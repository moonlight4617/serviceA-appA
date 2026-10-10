# ADR-0014: 共通資材はSSM Parameter Store経由で受け取る。
# terraform_remote_state は使わない。
#
# パラメータが存在しない場合、planがここで失敗する。
# これが「初回構築の順序（platform-infra → serviceA-infra → アプリ）」を
# 検知する仕組みになっている。パイプライン上の依存は作らない。

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# --- platform-infra が出力するもの -------------------------------------------

data "aws_ssm_parameter" "app_subnet_ids" {
  name = "/platform/${var.env}/app_subnet_ids"
}

data "aws_ssm_parameter" "app_security_group_id" {
  name = "/platform/${var.env}/app_security_group_id"
}

data "aws_ssm_parameter" "vpc_id" {
  name = "/platform/${var.env}/vpc_id"
}

data "aws_ssm_parameter" "alb_listener_arn" {
  name = "/platform/${var.env}/alb_listener_arn"
}

data "aws_ssm_parameter" "ecs_cluster_name" {
  name = "/platform/${var.env}/ecs_cluster_name"
}

# --- アプリ別の割り当て値（ALBの採番など） -----------------------------------

# ADR-0013: ALB 1台を3環境×複数アプリで共有するため、
# パス接頭辞と優先度は platform-infra が採番した値を使う。
# 自前で採番すると必ず衝突する
data "aws_ssm_parameter" "path_prefix" {
  name = "/platform/${var.env}/${var.service}-${var.app}/path_prefix"
}

data "aws_ssm_parameter" "listener_rule_priority" {
  name = "/platform/${var.env}/${var.service}-${var.app}/listener_rule_priority"
}

data "aws_ssm_parameter" "ecr_repository_url" {
  name = "/platform/${var.env}/${var.service}-${var.app}/ecr_repository_url"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # ADR-0006: リソース名は <service>-<app>-<env> で統一する。
  # platform-infra のIAMポリシーがこの形を前提に権限を絞っている
  name = "${var.service}-${var.app}-${var.env}"

  subnet_ids        = split(",", data.aws_ssm_parameter.app_subnet_ids.value)
  security_group_id = data.aws_ssm_parameter.app_security_group_id.value
  listener_arn      = data.aws_ssm_parameter.alb_listener_arn.value
  cluster_name      = data.aws_ssm_parameter.ecs_cluster_name.value
  path_prefix       = data.aws_ssm_parameter.path_prefix.value
  rule_priority     = tonumber(data.aws_ssm_parameter.listener_rule_priority.value)
  ecr_url           = data.aws_ssm_parameter.ecr_repository_url.value

  # ADR-0005: タグではなくdigestで固定する。
  # digestが未指定（初回構築時）はプレースホルダになる
  image = var.image_digest != "" ? "${local.ecr_url}@${var.image_digest}" : "${local.ecr_url}:bootstrap"

  container_name = var.app
  container_port = 8080
}
