# Created by the generate script
terraform {
  # required_version = "~> 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }    
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3"
    }
  }

  backend "s3" {
    bucket         = "sage-terraform-state-management"
    key            = "argocd/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"

    assume_role = {
      role_arn = "arn:aws:iam::974266546473:role/terraform"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::974266546473:role/terraform"
  }

  default_tags {
    tags = {
      Terraform      = "true"
      TerraformStack = "argo-cd"
      Environment    = "management"
    }
  }
}

provider "aws" {
  alias  = "dev"
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::136115413227:role/terraform"
  }

}

provider "aws" {
  alias  = "prod"
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::466115813883:role/terraform"
  }

}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_mgmt.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_mgmt.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", local.eks_cluster_name, "--role", local.terraform_runner_access_role_arn]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks_mgmt.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_mgmt.certificate_authority.0.data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", local.eks_cluster_name, "--role", local.terraform_runner_access_role_arn]
      command     = "aws"
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 15
  host                   = data.aws_eks_cluster.eks_mgmt.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_mgmt.certificate_authority.0.data)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.eks_cluster_name, "--role", "arn:aws:iam::974266546473:role/terraform"]
  }
}

# ref: https://registry.terraform.io/providers/hashicorp/dns/latest
provider "dns" {
  update {
    server = "ad1.domain.sagedining.com"

    gssapi {
      realm    = jsondecode(data.aws_secretsmanager_secret_version.ad_dns.secret_string)["realm"]
      username = jsondecode(data.aws_secretsmanager_secret_version.ad_dns.secret_string)["username"]
      password = jsondecode(data.aws_secretsmanager_secret_version.ad_dns.secret_string)["password"]
    }
  }
}
