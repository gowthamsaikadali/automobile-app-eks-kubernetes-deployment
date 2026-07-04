# Replaces the manual `kubectl apply -f components.yaml` step.
# Without this, HPA can't read CPU/memory and stays stuck at <unknown>.
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

  depends_on = [module.eks]
}
