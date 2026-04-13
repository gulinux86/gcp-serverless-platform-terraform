# Building a Production-Grade Serverless Platform on GCP with Terraform: What We Learned

There's a version of this post where I walk you through the architecture step by step, everything works perfectly, and I wrap it up with a neat list of best practices. This is not that post.

This is the version where I tell you about the Cloud Armor blind spot we shipped and didn't notice for a while, the Terraform destroy run that deleted the remote state bucket mid-teardown, and the GCP internal IP reservation that cannot be force-deleted no matter what you throw at it. Because those are the parts that will actually save you time.

Let's start with why we built this in the first place.

---

## Why Serverless-First? (The Case Against GKE)

When scoping the infrastructure for this project, GKE was the obvious first candidate. It's powerful, it's familiar, and it handles complex workloads well. We chose Cloud Run v2 instead, for reasons that became more compelling as the project progressed.

The workload is a standard two-tier web application: a frontend, a backend API, and a PostgreSQL database. Traffic patterns are uneven — bursty during business hours, quiet overnight. GKE would give us a cluster that sits mostly idle and charges us for the privilege. Cloud Run gives us scale-to-zero with a cold start penalty that, for this workload, is acceptable.

More importantly: **GKE is an operations surface that this project doesn't need**. Node pool upgrades, cluster autoscaler tuning, PodDisruptionBudgets, resource requests and limits per pod — all of that is real work that generates zero business value for a two-service app. Cloud Run v2 eliminates the entire category.

What we traded away: fine-grained scheduling, stateful workloads, and sidecar containers (mostly). What we gained: no cluster management, automatic scaling, per-request billing, and Direct VPC Egress — which turned out to be the right call.

**Cloud Run v2 specifically** (not the original Cloud Run) matters here because of Direct VPC Egress. Instead of routing through a VPC Access Connector (a managed resource with its own throughput limits and scaling behavior), Direct VPC Egress drops Cloud Run instances directly into our VPC subnet. This means private Cloud SQL access without a proxy, lower latency, and no connector bottleneck to tune.

---

## The Two-Layer Architecture

The project splits infrastructure into two Terraform root modules: `foundation` and `workload`. The root `main.tf` orchestrates both.

```
foundation/          →  VPC, subnets, PSA, firewall
workload/            →  Cloud Run, LB, SQL, secrets, IAM
modules/             →  reusable building blocks for both
```

This split is not just organizational tidiness — it encodes a hard dependency contract. Foundation creates the network. Workload consumes it. Foundation must outlive workload; workload must be gone before foundation teardown begins.

In practice this means:

```hcl
module "workload" {
  source = "./workload"
  ...
  vpc_network_id    = module.foundation.vpc_network_id
  private_subnet_id = module.foundation.private_subnet_id

  depends_on = [module.foundation]
}
```

The `depends_on` enforces creation order. The inverse — workload destroyed before foundation — is enforced by how Terraform resolves the dependency graph on destroy. Because workload depends on foundation outputs, Terraform knows foundation can't be destroyed while workload exists.

What the module split doesn't handle by itself: the *timing* of GCP's internal resource release. That requires something more deliberate.

---

## The Destroy Orchestration Problem

Running `terraform destroy` on this infrastructure is a 15–25 minute operation. Not because there are that many resources, but because of how Cloud Run Direct VPC Egress interacts with VPC lifecycle management.

When a Cloud Run service with Direct VPC Egress is running, GCP reserves IP addresses from your subnet for the service instances. These look like this:

```
NAME                                  TYPE        SUBNET            STATUS
serverless-ipv4-1775931706322706294   INTERNAL    app-vpc-private   RESERVED
```

When you delete the Cloud Run service, GCP doesn't release these reservations immediately. There's an asynchronous cleanup process that typically runs 5–30 minutes after service deletion. If you try to delete the subnet before GCP releases those IPs, you get:

```
Error: The subnetwork resource 'app-vpc-private' is already being used by
'projects/.../addresses/serverless-ipv4-1775931706322706294'
```

The address cannot be force-deleted. It's owned by GCP's internal Serverless infrastructure (`//serverless.googleapis.com/...`) and has no public API for deletion. You wait.

We handle this with `time_sleep` resources:

```hcl
# In modules/workload/cloud_run_service/main.tf
resource "time_sleep" "wait_for_ip_release" {
  destroy_duration = "150s"
}

resource "google_cloud_run_v2_service" "this" {
  depends_on = [time_sleep.wait_for_ip_release]
  ...
}
```

The `depends_on` here runs *backwards* on destroy. Because `cloud_run_v2_service` depends on `wait_for_ip_release`, Terraform destroys the Cloud Run service first, then waits 150 seconds before considering the module fully torn down. The foundation subnet can only be deleted after the workload module (including this timer) completes.

There's a second timer in the VPC module for PSA (Private Service Access):

```hcl
resource "time_sleep" "decommissioning_buffer" {
  destroy_duration = "600s"   # 10 minutes
  depends_on = [google_service_networking_connection.default]
}
```

After the subnet is deleted, GCP holds internal PSA locks for several minutes. The 10-minute buffer prevents the peering range deletion from failing. Without it, the destroy would fail inconsistently depending on how fast GCP's internal state propagates.

---

## The Cloud Armor Security Gap

This is the part I'm most embarrassed about, and also the part most worth documenting.

The original architecture had the Global HTTPS Load Balancer routing all traffic to the frontend Cloud Run service. The frontend would then proxy `/api/*` requests to the backend via Direct VPC Egress (service-to-service over VPC). Cloud Armor was attached to the LB's backend service, which pointed at the frontend.

The problem: **Cloud Armor only inspected traffic destined for the frontend**. API requests entered Cloud Armor at the LB, then traveled through the frontend container before reaching the backend. At the container layer, there's no WAF.

```
BEFORE (broken):
Internet → Cloud Armor → frontend → backend API
                ↑
           WAF only here
           (API traffic exits WAF coverage at frontend container)
```

Worse: the backend Cloud Run service had no ingress restriction. Its `*.run.app` URL was reachable directly from the internet, bypassing Cloud Armor entirely.

The fix was to move routing into the LB itself. Instead of proxying at the application layer, we added a second Serverless NEG and path rules to the URL map:

```hcl
path_rule {
  paths   = ["/api", "/api/*"]
  service = google_compute_backend_service.api[0].self_link
}
```

And attached Cloud Armor to both backend services:

```hcl
resource "google_compute_backend_service" "api" {
  security_policy = var.security_policy_id   # same policy
  ...
}
```

Now the traffic flow is:

```
AFTER (correct):
Internet → Cloud Armor → URL Map → /api/* → backend (WAF covered)
                              └──→ /* → frontend (WAF covered)
```

The frontend-to-backend proxy pattern, the `API_URL` environment variable, and the `roles/run.invoker` IAM binding from `frontend-sa` to the backend — all removed. The LB is the single entry point. Both services lock ingress to `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`.

**Lesson: design your WAF coverage before you design your routing.** The WAF should be as close to the entry point as possible and should cover all traffic paths, not just the "main" one.

---

## A Bug That Almost Cost Us the State File

During a `terraform destroy` run, we hit an unexpected problem: the destroy sequence tried to delete the remote state bucket *while the destroy was still in progress*.

The root cause was a location mismatch. The state bucket was originally created with `location = "US-CENTRAL1"` (regional), but the Terraform code declared `location = "US"` (multi-region). When Terraform compared state to config, it saw a location change — which forces a bucket replacement. Replace means: delete the old bucket, create a new one.

```
module.foundation.google_storage_bucket.state_bucket  must be replaced
  ~ location = "US-CENTRAL1" → "US"  # forces replacement
```

If the old bucket (containing the state file) had been destroyed before the new one was created, we would have lost the state entirely. No recovery path. All existing GCP resources would become unmanaged "orphans" with no way to run `terraform destroy` on them.

The fix was simple: align the code to match reality (`location = "US-CENTRAL1"`). The lesson is more nuanced:

**The `terraform plan` output is the most important thing you read before every apply.** We had been skimming plans and looking for "add/change/destroy" summaries. We should have been reading the details. A `# forces replacement` annotation on your state bucket is not a detail — it's a catastrophic event waiting to happen.

---

## The HTTP Proxy Wiring Bug

After implementing the path-based LB routing, `/api/*` requests were still returning frontend responses. `terraform plan` showed the path-based URL map (`with_api`) was created. `terraform state show` confirmed the path rules were correct. But requests weren't routing correctly.

The problem was subtler: the HTTP target proxy was pointing to the wrong URL map.

```
# What we thought:
HTTP proxy → path-based URL map → /api/* → backend

# What was actually happening:
HTTP proxy → redirect URL map → frontend (everything)
           ↑
         This is the wrong URL map
```

When we made the HTTPS redirect URL map conditional on `var.domain`, we introduced the following logic:

```hcl
resource "google_compute_target_http_proxy" "redirect" {
  url_map = google_compute_url_map.redirect.self_link  # always the redirect map
}
```

But the redirect map, when no domain is configured, just routes everything to the frontend backend service. The path-based `with_api` URL map existed in state but had no proxy pointing to it — a dead resource.

The one-line fix:

```hcl
url_map = var.domain != null
  ? google_compute_url_map.redirect.self_link   # HTTP → HTTPS redirect
  : local.url_map_self_link                     # path-based routing
```

**Lesson: when introducing conditional resources, trace every reference path.** We created `local.url_map_self_link` to abstract away which URL map was active — but then didn't use it consistently. Read the dependency graph, not just the resource definitions.

---

## What We'd Do Differently

**1. Set `force_destroy = true` on the state bucket from day one.**
The state bucket should not block destroy operations. Yes, you want protection against accidental deletion in normal operation. But in a destroy scenario, you've already committed. Making the state bucket self-destruct with the rest of the infrastructure is the right behavior.

**2. Lock down ingress defaults earlier.**
The `cloud_run_service` module defaulted to `INGRESS_TRAFFIC_ALL` initially. Changing a default is a breaking change to all callers. We had to explicitly set `ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"` in every call site after the fact. Default to `INGRESS_TRAFFIC_INTERNAL_ONLY` from the start — make public access opt-in.

**3. Design the LB module for multiple backends from the beginning.**
The `https_load_balancer` module was initially built for a single backend. Adding the second backend (API path routing) required a significant interface change and introduced a conditional complexity (`count`-based resources) that led to the URL map wiring bug. A `backends` input variable from day one would have avoided this.

**4. Plan for the GCP Serverless IP release delay in runbooks.**
Document explicitly: if you delete Cloud Run services outside of `terraform destroy` (e.g., via Console or `gcloud`), wait 30+ minutes before attempting to delete the VPC. This is not documented anywhere obvious in GCP's docs and burns people regularly.

---

## Takeaways

The architecture that emerged from this project — Cloud Run v2 with Direct VPC Egress, path-based LB routing, Cloud Armor on all backends, PSA for Cloud SQL, automated secret rotation — is solid. The patterns are reusable. The `time_sleep` teardown choreography is a solved problem.

The bugs were instructive. The Cloud Armor gap taught us to think about WAF coverage holistically, not per-service. The state bucket near-miss taught us to read plans carefully. The URL map wiring bug taught us to trace reference paths when introducing conditional resources.

None of these would be obvious from reading the final code. That's why they're worth writing down.

---

*The full Terraform source for this architecture is in this repository. See [ARCHITECTURE.md](../ARCHITECTURE.md) for the complete system diagram and reference documentation.*
