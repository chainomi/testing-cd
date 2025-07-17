output "argocd_alb_dns" {
  description = "ArgoCD load balancer DNS name"
  value       = data.kubernetes_ingress_v1.ingress.status.0.load_balancer.0.ingress.0.hostname
  depends_on  = [helm_release.argo-cd, time_sleep.wait_60_seconds]
}

