# Runbook — foundation destroy blocked by `serverless-ipv4-*`

**Severity:** low (teardown is delayed, nothing is broken or exposed)
**Applies to:** `terraform-destroy` on the `foundation` layer, any environment

---

## Symptom

`terraform destroy` on the foundation layer fails while deleting the private
subnet:

```
Error: Error when reading or editing Subnetwork: googleapi: Error 400:
The subnetwork resource 'projects/<p>/regions/us-central1/subnetworks/app-<env>-vpc-private'
is already being used by
'projects/<p>/regions/us-central1/addresses/serverless-ipv4-<id>',
resourceInUseByAnotherResource
```

The secondary subnet (`-private-2`) deletes normally. Only the subnet Cloud Run
attached to is affected.

---

## Cause

Cloud Run uses **Direct VPC Egress** (see ARCHITECTURE.md §Cloud Run egress).
When a service attaches to the subnet, GCP creates one compute address with
`purpose: SERVERLESS` inside it. That address is in turn held by an
`addressReservation` belonging to `serverless.googleapis.com`:

```
subnet  ◄──  address (purpose: SERVERLESS)  ◄──  addressReservation
                                                 (serverless.googleapis.com)
```

After the Cloud Run services are deleted the reservation is released
**asynchronously, with no documented upper bound**. Until then the address keeps
the subnet pinned.

There is one such address per subnet attachment — not one per Cloud Run instance.

---

## What does NOT work

| Attempt | Result |
|---|---|
| `gcloud compute addresses delete serverless-ipv4-<id>` | `The address resource ... is already being used by '//serverless.googleapis.com/.../addressReservations/...'` |
| Deleting the reservation via API | `serverless.googleapis.com/v1/.../addressReservations` returns **404** — not a public endpoint |
| Waiting a fixed interval before the destroy | Unreliable — see the measurement below |

### Measured release time

One full teardown was instrumented (2026-08-11, `hml`, `us-central1`):

| Event | Time (UTC) |
|---|---|
| Reservation created (workload apply, Cloud Run attaches) | 19:42 |
| Cloud Run services / jobs / revisions all deleted | ~20:2x |
| Workload layer fully destroyed, both 150s cooldowns elapsed | before 21:00 |
| Reservation still `RESERVED` | 21:05 |
| Reservation released | **21:49** |

**~2h07 from creation, at least ~1h20 after the last service was deleted.** This
is a single sample against a behaviour with no published SLA — treat it as an
order of magnitude, not a guarantee. Timeouts of 30 and 60 minutes were both
tried during this incident and both would have failed a healthy teardown.

Do not spend time hunting for a consumer to delete. Confirm there is none and
then wait:

```bash
gcloud run services list  --project="$P"                       # expect: 0 items
gcloud run jobs list      --project="$P" --region="$REGION"    # expect: 0 items
gcloud run revisions list --project="$P" --region="$REGION"    # expect: 0 items
```

---

## Resolution

The `terraform-destroy` workflow gates the foundation destroy on this: it polls
every 60s for up to 120 minutes and only then runs `terraform destroy`. In normal
operation no action is needed — the run takes longer, that is all.

> **Design note.** Holding a CI job for up to two hours is a blunt instrument. It
> is acceptable here because Actions minutes are not a constraint for this repo
> and the alternative (fail fast, re-run later) trades automation for toil. If the
> wait becomes a problem, the better shape is a scheduled workflow that retries
> the foundation destroy until it succeeds, rather than a job that blocks.

**There is no urgency.** Everything billable (Cloud Run, Cloud SQL, the load
balancer) is destroyed with the workload layer. What remains pinned — VPC,
subnets, PSA range, peering — is free. A foundation destroy that has to wait, or
be re-run tomorrow, costs nothing.

If the gate times out, or you are destroying locally:

**1. Confirm the reservation is the only thing left.**

```bash
P=<project-id>; REGION=us-central1
gcloud compute addresses list --project="$P" --regions="$REGION" \
  --filter="purpose=SERVERLESS" \
  --format="table(name,address,status,creationTimestamp)"
```

**2. Wait for it to disappear.** Poll rather than guess:

```bash
until [ "$(gcloud compute addresses list --project="$P" --regions="$REGION" \
           --filter='purpose=SERVERLESS' --format='value(name)' | wc -l)" -eq 0 ]; do
  echo "still reserved — $(date +%H:%M:%S)"; sleep 60
done
```

**3. Re-run the foundation destroy.**

```
terraform-destroy → environment: <env> → layer: foundation
```

The foundation state is intact between attempts; the failed run only stops
before the subnet. Re-running is safe and idempotent.

---

## Notes

- This is the known cost of Direct VPC Egress and is accepted deliberately. The
  Serverless VPC Access Connector avoids it, but could not be provisioned in this
  project — the evidence is in ARCHITECTURE.md §Cloud Run egress.
- Record how long the release actually took. There is no published SLA, and a
  local sample is the only basis for tuning the gate's 30-minute timeout.
- Nothing is billed while the reservation is held: it is an internal IP in a
  private subnet.
