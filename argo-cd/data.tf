# Data source - management account - for helm provider
data "aws_eks_cluster" "eks_mgmt" {
  name = local.eks_cluster_name
}

## Get oidc arn for service account policy
data "aws_iam_openid_connect_provider" "eks_mgmt" {
  url = data.aws_eks_cluster.eks_mgmt.identity[0].oidc[0].issuer # Replace with your OIDC provider URL
}

# Data source - development account - for helm chart values
data "aws_eks_cluster" "eks_dev" {
  provider = aws.dev
  name     = local.development_eks_cluster_name
}

# Data source - production account - for helm chart values
data "aws_eks_cluster" "eks_prod" {
  provider = aws.prod
  name     = local.production_eks_cluster_name
}

# Data source for gitlab repo secret from
data "aws_secretsmanager_secret_version" "gitlab_argocd" {
  secret_id = local.gitlab_secret_name
}

# Data sources for DNS - This secret exists in prod, dev, and mgmt
data "aws_secretsmanager_secret_version" "ad_dns" {
  secret_id = local.dns_secret_id
}

# Getting ArgoCD ingress / alb dns address for DNS record
data "kubernetes_ingress_v1" "ingress" {
  metadata {
    name      = "argo-cd-argocd-server"
    namespace = local.argocd_namespace
  }
  depends_on = [helm_release.argo-cd, time_sleep.wait_60_seconds]
}

