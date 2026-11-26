# handover.tftest.hcl
#
# Trade-off context:
#   This module is the line between Terraform and Argo CD. Terraform owns the
#   privilege boundary (AppProjects) and exactly one Application; everything else
#   comes from Git. The tests keep the values that define that boundary flowing
#   into the chart, because a dropped `set` is silent: Helm renders an empty list
#   and the project accepts nothing — or, worse, a default you did not review.

mock_provider "helm" {}

variables {
  namespace              = "argocd"
  platform_repo_url      = "https://github.com/example/platform"
  platform_repo_revision = "main"
  platform_repo_path     = "bootstrap/apps"
  apps_repo_url          = "https://github.com/example/platform"
  apps_namespaces        = ["frontend-*", "backend-*"]
  platform_source_repos  = ["https://github.com/example/platform", "https://charts.jetstack.io"]
  apps_source_repos      = ["https://github.com/example/platform"]
}

run "boundary_values_reach_the_chart" {
  command = plan

  assert {
    condition     = one([for s in helm_release.bootstrap.set : s.value if s.name == "appsNamespaces"]) == "{frontend-*,backend-*}"
    error_message = "apps_namespaces must be passed to the chart as a Helm list."
  }

  assert {
    condition     = one([for s in helm_release.bootstrap.set : s.value if s.name == "platformRepoPath"]) == "bootstrap/apps"
    error_message = "The root Application must watch the configured directory."
  }

  assert {
    condition     = one([for s in helm_release.bootstrap.set : s.value if s.name == "platformSourceRepos"]) == "{https://github.com/example/platform,https://charts.jetstack.io}"
    error_message = "Chart repositories must reach the platform project's sourceRepos."
  }
}

run "chart_is_local" {
  command = plan

  assert {
    condition     = endswith(helm_release.bootstrap.chart, "/chart")
    error_message = "The bootstrap must ship as the module's local chart; kubernetes_manifest cannot plan Argo CD CRs before the CRDs exist."
  }
}
