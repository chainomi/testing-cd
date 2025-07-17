# Config
# =============================================================================
locals {
  # Cluster
  eks_cluster_name             = "mgmt-sage"
  development_eks_cluster_name = "dev-sage"
  production_eks_cluster_name  = "prod-sage"

  # ArgoCD
  argocd_namespace                                   = "argocd"
  argocd_service_account_name                        = "argocd-server"
  argocd_application_controller_service_account_name = "argocd-application-controller"
  argocd_admin_password                              = bcrypt(jsondecode(data.aws_secretsmanager_secret_version.gitlab_argocd.secret_string)["admin_password"])

  # DNS
  domain_zone     = "aws.sagedining.com"
  sub_domain_name = "argocd"
  dns_secret_id   = "ad-dns"

  # Repo information
  gitlab_url                    = "https://devrepo2.dev.sagedining.com"
  gitlab_project_id             = "301"
  gitlab_repo_branch            = "main"
  gitlab_demo_repo              = "${local.gitlab_url}/hcm/eks-demo-charts.git"
  gitlab_infra_repo             = "${local.gitlab_url}/infrastructure/argocd.git"
  gitlab_secret_name            = "argocd"
  gitlab_repo_token             = jsondecode(data.aws_secretsmanager_secret_version.gitlab_argocd.secret_string)["gitlab_token"]
  gitlab_pipeline_trigger_token = jsondecode(data.aws_secretsmanager_secret_version.gitlab_argocd.secret_string)["gitlab_pipeline_trigger_token"]

  # SSO - Azure OIDC
  azure_directory_tenant_id = jsondecode(data.aws_secretsmanager_secret_version.gitlab_argocd.secret_string)["azure_directory_tenant_id"]
  azure_group_object_ids = {
    systems_team = jsondecode(data.aws_secretsmanager_secret_version.gitlab_argocd.secret_string)["azure_group_object_id_systems_team"]
  }
  azure_ad_application_client_id = jsondecode(data.aws_secretsmanager_secret_version.gitlab_argocd.secret_string)["azure_application_client_id"]
  azure_client_secret            = jsondecode(data.aws_secretsmanager_secret_version.gitlab_argocd.secret_string)["azure_client_secret"]

  # For Kubnernetes and Helm provider configuration needed to deploy k8s resources to cluster
  terraform_runner_access_role_arn = "arn:aws:iam::974266546473:role/terraform"
}

# Helm Chart for ArgoCD
# =============================================================================
resource "helm_release" "argo-cd" {
  name             = "argo-cd"
  version          = "7.5.2"
  namespace        = local.argocd_namespace
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  create_namespace = true

  values = [templatefile("${path.module}/helm-values/values.yaml",
    {
      domain = "${local.sub_domain_name}.${local.domain_zone}"

      # access
      argocd_admin_password = local.argocd_admin_password

      # ingress (alb) config
      alb_cert_arn = "arn:aws:acm:us-east-1:974266546473:certificate/2927ba4c-99a0-4154-b77b-f6dfc97fb55e"

      # cluster config
      development_cluster_name       = local.development_eks_cluster_name
      development_cluster_api_server = data.aws_eks_cluster.eks_dev.endpoint
      development_cluster_cicd_role  = "arn:aws:iam::136115413227:role/eks-cicd"
      development_cluster_ca_cert    = data.aws_eks_cluster.eks_dev.certificate_authority.0.data

      production_cluster_name       = local.production_eks_cluster_name
      production_cluster_api_server = data.aws_eks_cluster.eks_prod.endpoint
      production_cluster_cicd_role  = "arn:aws:iam::466115813883:role/eks-cicd"
      production_cluster_ca_cert    = data.aws_eks_cluster.eks_prod.certificate_authority.0.data

      # service account irsa (iam role for service account)
      service_account_name                        = local.argocd_service_account_name
      service_account_annotation                  = "{eks.amazonaws.com/role-arn: ${aws_iam_role.argo_cicd.arn}}"
      application_controller_service_account_name = local.argocd_application_controller_service_account_name

      # repo config
      gitlab_repo_token     = local.gitlab_repo_token
      gitlab_demo_repo_url  = local.gitlab_demo_repo
      gitlab_infra_repo_url = local.gitlab_infra_repo

      # SSO - Azure OIDC
      directory_tenant_id            = local.azure_directory_tenant_id
      group_object_id_systems_team   = local.azure_group_object_ids.systems_team
      azure_ad_application_client_id = local.azure_ad_application_client_id
      client_secret                  = local.azure_client_secret
  })]
}

# Sleep to allow for provisioning of k8s resources in cluster
# =============================================================================
resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"
  depends_on      = [helm_release.argo-cd]
}

# DNS Record
# =============================================================================
resource "dns_cname_record" "argocd" {
  zone       = "${local.domain_zone}."
  name       = local.sub_domain_name
  cname      = "${data.kubernetes_ingress_v1.ingress.status.0.load_balancer.0.ingress.0.hostname}."
  ttl        = 60
  depends_on = [data.kubernetes_ingress_v1.ingress]
}

#Trigger gitlab pipeline to deploy ArgoCD apps and projects from charts repo

resource "null_resource" "trigger_pipeline" {
  # The 'triggers' block is used here to force the null_resource to run on each apply.
  # Remove or adjust this if you want the pipeline to trigger only under specific conditions.
  triggers = {
    trigger_time = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -X POST \
      --fail --request POST "${local.gitlab_url}/api/v4/projects/${local.gitlab_project_id}/trigger/pipeline" \
      --form token=${local.gitlab_pipeline_trigger_token} \
      --form ref=${local.gitlab_repo_branch}
    EOT
  }
  depends_on = [dns_cname_record.argocd]
}

