terraform {
  # S3ネイティブロック（use_lockfile）のため 1.10 以上（ADR-0007）。
  # 共通ワークフローが使うバージョンと揃える
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

provider "aws" {
  region = var.region

  # ADR-0006: 1アカウント内の環境分離はタグとリソース名で行う。
  # platform-infra のIAMポリシーがこのタグを前提に権限を絞っているため、
  # タグが欠けるとapplyが失敗する
  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Repository  = "serviceA-appA"
      Service     = "serviceA"
      App         = "appA"
      Environment = var.env
    }
  }
}
