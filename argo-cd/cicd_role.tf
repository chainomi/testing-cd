locals {
  # eks cicd role arn hardcoded here due to circular reference when using module.eks_cicd_roles.role_arn as input value for cicd_runner_access_role_arn input in module.eks
  eks_cicd_role_arn = "arn:aws:iam::974266546473:role/eks-cicd"
  general_iam_role_arns = ["arn:aws:iam::974266546473:role/argocd-cicd"]
  node_group_iam_role_arns = [for node_group in module.eks.node_group_map : node_group.iam_role_arn]
}

module "eks_cicd_roles" {
  source = "../../../modules/eks-cicd-iam-roles"

  # allowing roles in local to assume eks-cicd role
  assume_role_principal_arns = concat(local.general_iam_role_arns, local.node_group_iam_role_arns)
}

