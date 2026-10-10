output "service_name" {
  description = "ECSサービス名"
  value       = aws_ecs_service.app.name
}

output "task_definition_arn" {
  description = "適用されたタスク定義のARN。リリース記録に残す（ADR-0010）"
  value       = aws_ecs_task_definition.app.arn
  sensitive   = true
}

output "deployed_image" {
  description = "デプロイされたイメージ。digestで固定されていることを確認できる（ADR-0005）"
  value       = local.image
  sensitive   = true
}

output "url_path" {
  description = "ALB上のパス接頭辞（ADR-0013）"
  # path_prefix は data.aws_ssm_parameter 由来のため、Terraformは
  # 自動的にsensitiveとして扱う。outputに出すには明示的な解除が必要。
  #
  # /dev/appA のようなパスは機密ではないため nonsensitive() で解除する。
  # バケット名やARNを含むものは解除してはいけない（ADR-0002）。
  value = nonsensitive(local.path_prefix)
}

output "log_group" {
  description = "CloudWatch Logsのロググループ"
  value       = aws_cloudwatch_log_group.app.name
}
