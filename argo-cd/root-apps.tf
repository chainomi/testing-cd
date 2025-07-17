locals {
  argo_project_names = {
    infrastructure = "infrastructure"
  }
  destination_servers = {
    development = data.aws_eks_cluster.eks_dev.endpoint
    management  = "https://kubernetes.default.svc"
    production  = data.aws_eks_cluster.eks_prod.endpoint
  }
  app_folder_paths = {
    development = "environments/development"
    management  = "environments/management"
    production  = "environments/production"
  }
  app_repo_target_revision = "HEAD"
}

# Bootstrap - root applications - infrastructure
#===========================

resource "kubectl_manifest" "argocd_infrastructure_project" {
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: ${local.argo_project_names.infrastructure}
  namespace: ${local.argocd_namespace}
  # Finalizer that ensures that project is not deleted until it is not referenced by any application
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  description: Infrastructure argocd project
  # Allow manifests to deploy from any Git repos
  sourceRepos:
  - '*'
  # Only permit applications to deploy to the flask-api namespace in the same cluster
  destinations:
  - namespace: '*'
    server: ${local.destination_servers.development}
  - namespace: '*'
    server: ${local.destination_servers.management}
  - namespace: '*'
    server: ${local.destination_servers.production}
YAML
}

resource "kubectl_manifest" "development_root_app" {
  yaml_body  = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dev-infra-root-app
  namespace: ${local.argocd_namespace}
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  destination:
    server: ${local.destination_servers.development}
    namespace: '*'
  project: ${local.argo_project_names.infrastructure}
  source:
    path: ${local.app_folder_paths.development}
    repoURL: ${local.gitlab_infra_repo}
    targetRevision: ${local.app_repo_target_revision}
    directory:
      recurse: true

  syncPolicy:
    automated: # automated sync by default retries failed attempts 5 times with following delays between attempts ( 5s, 10s, 20s, 40s, 80s ); retry controlled using `retry` field.
      prune: true # Specifies if resources should be pruned during auto-syncing ( false by default ).  
    syncOptions:     # Sync options which modifies sync behavior
    - CreateNamespace=true # Namespace Auto-Creation ensures that namespace specified as the application destination exists in the destination cluster.     
YAML
  depends_on = [kubectl_manifest.argocd_infrastructure_project]
}

resource "kubectl_manifest" "management_root_app" {
  yaml_body  = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mgmt-infra-root-app
  namespace: ${local.argocd_namespace}
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  destination:
    server: ${local.destination_servers.management}
    namespace: '*'
  project: ${local.argo_project_names.infrastructure}
  source:
    path: ${local.app_folder_paths.management}
    repoURL: ${local.gitlab_infra_repo}
    targetRevision: ${local.app_repo_target_revision}
    directory:
      recurse: true

  syncPolicy:
    automated: # automated sync by default retries failed attempts 5 times with following delays between attempts ( 5s, 10s, 20s, 40s, 80s ); retry controlled using `retry` field.
      prune: true # Specifies if resources should be pruned during auto-syncing ( false by default ).  
    syncOptions:     # Sync options which modifies sync behavior
    - CreateNamespace=true # Namespace Auto-Creation ensures that namespace specified as the application destination exists in the destination cluster.     
YAML
  depends_on = [kubectl_manifest.argocd_infrastructure_project]
}

resource "kubectl_manifest" "production_root_app" {
  yaml_body  = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prod-infra-root-app
  namespace: ${local.argocd_namespace}
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  destination:
    server: ${local.destination_servers.production}
    namespace: '*'
  project: ${local.argo_project_names.infrastructure}
  source:
    path: ${local.app_folder_paths.production}
    repoURL: ${local.gitlab_infra_repo}
    targetRevision: ${local.app_repo_target_revision}
    directory:
      recurse: true

  syncPolicy:
    automated: # automated sync by default retries failed attempts 5 times with following delays between attempts ( 5s, 10s, 20s, 40s, 80s ); retry controlled using `retry` field.
      prune: true # Specifies if resources should be pruned during auto-syncing ( false by default ).  
    syncOptions:     # Sync options which modifies sync behavior
    - CreateNamespace=true # Namespace Auto-Creation ensures that namespace specified as the application destination exists in the destination cluster.     
YAML
  depends_on = [kubectl_manifest.argocd_infrastructure_project]
}