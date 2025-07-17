locals {
  policies = {
    eks_cicd = {
      description = "EKS full access for EKS CICD role"
      policy = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect   = "Allow"
            Action   = "eks:*"
            Resource = "*"
          }
        ]
      }
    }
  }
}

resource "aws_iam_policy" "this" {
  for_each    = local.policies
  name        = each.key
  description = each.value.description
  policy      = jsonencode(each.value.policy)
}

resource "aws_iam_role" "this" {
  name = "eks-cicd"

  description = "Assumed by Gitlab k8s runner to deploy resources to deploy k8s resources to EKS clusters in AWS account"

  # using for loop on list from assume_role_principal_arns variable to create multiple assume role statetments
  # assume_role_policy = jsonencode({
  #   Version = "2012-10-17"
  #   Statement = [
  #     for arn in var.assume_role_principal_arns : {
  #       Effect = "Allow"
  #       Principal = {
  #         AWS = arn
  #       }
  #       Action = "sts:AssumeRole"
  #     }
  #   ]
  # })

  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  # joining list of policy arns from policies created in aws_iam.policy.this and a list of AWS managed policies
  managed_policy_arns = concat([for policy in aws_iam_policy.this : policy.arn], ["arn:aws:iam::aws:policy/AmazonEKSServicePolicy"])

}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.assume_role_principal_arns
    }
}
}

output "policy_arns" {
  value = concat([for policy in aws_iam_policy.this : policy.arn], ["arn:aws:iam::aws:policy/AmazonEKSServicePolicy"])
}

output "role_arn" {
  value = aws_iam_role.this.arn
}
