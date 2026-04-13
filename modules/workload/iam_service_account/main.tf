resource "google_service_account" "this" {
  account_id   = var.account_id
  display_name = var.display_name
  description  = var.description
  project      = var.project_id
}

resource "google_service_account_key" "this" {
  count              = var.create_key ? 1 : 0
  service_account_id = google_service_account.this.name
  public_key_type    = var.public_key_type
}

resource "google_project_iam_member" "this" {
  for_each = var.iam_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}

resource "google_service_account_iam_member" "this" {
  for_each = var.service_account_iam_roles

  service_account_id = google_service_account.this.name
  role               = each.value
  member             = each.key
}

