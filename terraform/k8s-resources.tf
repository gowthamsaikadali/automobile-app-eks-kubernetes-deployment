# These replace the manual `kubectl apply -f 00-namespaces.yaml`,
# `01-configmap.yaml`, and `kubectl create secret` steps. Now they're
# created automatically as part of `terraform apply`, and secret values
# come from Terraform variables (sensitive, never in state in plaintext logs,
# never committed to Git) instead of typed manually into the terminal.

resource "kubernetes_namespace" "dev" {
  metadata {
    name   = "dev"
    labels = { environment = "dev" }
  }
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "prod" {
  metadata {
    name   = "prod"
    labels = { environment = "prod" }
  }
  depends_on = [module.eks]
}

resource "kubernetes_config_map" "dev" {
  metadata {
    name      = "autoforge-config"
    namespace = kubernetes_namespace.dev.metadata[0].name
  }
  data = {
    APP_ENV        = "development"
    LOG_LEVEL      = "debug"
    FEATURE_NEW_UI = "true"
  }
}

resource "kubernetes_config_map" "prod" {
  metadata {
    name      = "autoforge-config"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }
  data = {
    APP_ENV        = "production"
    LOG_LEVEL      = "warn"
    FEATURE_NEW_UI = "false"
  }
}

resource "kubernetes_secret" "dev" {
  metadata {
    name      = "autoforge-secret"
    namespace = kubernetes_namespace.dev.metadata[0].name
  }
  data = {
    DB_USERNAME = var.dev_db_username
    DB_PASSWORD = var.dev_db_password
  }
  type = "Opaque"
}

resource "kubernetes_secret" "prod" {
  metadata {
    name      = "autoforge-secret"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }
  data = {
    DB_USERNAME = var.prod_db_username
    DB_PASSWORD = var.prod_db_password
  }
  type = "Opaque"
}
