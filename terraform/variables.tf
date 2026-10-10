variable "region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "env" {
  description = "環境名。env/<env>.tfvars で指定する（workspaceは使わない。ADR-0007）"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.env)
    error_message = "env は dev / stage / prod のいずれかで指定してください。"
  }
}

variable "service" {
  description = "サービス名。.platform/app.yaml と一致させる"
  type        = string
  default     = "serviceA"
}

variable "app" {
  description = "アプリ名。.platform/app.yaml と一致させる"
  type        = string
  default     = "appA"
}

variable "image_digest" {
  description = <<-EOT
    デプロイするイメージのdigest（sha256:...）。

    ADR-0005: タグではなくdigestで指定する。タグは後から付け替えられるため、
    digestでなければ「stageで確認したものがprodに出る」ことを保証できない。

    CDワークフローが実際の値を渡す。空の場合は初回構築用の
    プレースホルダになるため、planに差分が出る。
  EOT
  type        = string
  default     = ""

  validation {
    # ADR-0005: stage/prodでは必ず検証済みの成果物をdigestで指定させる
    condition     = var.env == "dev" || var.image_digest != ""
    error_message = "stage / prod では image_digest の指定が必須です（ADR-0005）。"
  }

  validation {
    condition     = var.image_digest == "" || can(regex("^sha256:[0-9a-f]{64}$", var.image_digest))
    error_message = "image_digest は sha256:<64桁の16進数> の形式で指定してください。"
  }
}

variable "commit_sha" {
  description = <<-EOT
    デプロイ対象のcommit SHA。コンテナの環境変数として注入し、
    稼働中のアプリが自分の出自を答えられるようにする。
    DynamoDBのリリース記録（ADR-0010）との突き合わせに使う。
  EOT
  type        = string
  default     = "unknown"
}

variable "desired_count" {
  description = "ECSサービスのタスク数"
  type        = number
  default     = 1
}

variable "cpu" {
  description = "Fargateのvcpu（1024 = 1vCPU）"
  type        = string
  default     = "512"
}

variable "memory" {
  description = "Fargateのメモリ（MiB）"
  type        = string
  default     = "1024"
}

variable "log_retention_days" {
  description = "CloudWatch Logsの保持日数"
  type        = number
  default     = 30
}
