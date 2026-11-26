# install.tftest.hcl
#
# Trade-off context:
#   Two settings in this release protect the cluster from Terraform itself:
#   crds.keep stops a `helm uninstall` from cascade-deleting every Application,
#   and a ClusterIP server keeps the UI off the internet until exposing it is a
#   reviewed decision. The version validation keeps "latest" out of a pinned
#   platform.

mock_provider "helm" {}

run "crds_survive_uninstall" {
  command = plan

  assert {
    condition     = one([for s in helm_release.argocd.set : s.value if s.name == "crds.keep"]) == "true"
    error_message = "crds.keep must be true: deleting the CRDs deletes every Application object in the cluster."
  }
}

run "server_not_exposed_by_default" {
  command = plan

  assert {
    condition     = one([for s in helm_release.argocd.set : s.value if s.name == "server.service.type"]) == "ClusterIP"
    error_message = "The Argo CD server must default to ClusterIP; exposing it needs ingress, TLS and SSO decided first."
  }
}

run "chart_version_must_be_exact" {
  command = plan

  variables {
    chart_version = "latest"
  }

  expect_failures = [var.chart_version]
}
