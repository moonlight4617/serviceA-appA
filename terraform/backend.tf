# ADR-0002: バケット名をコードに書かないため partial configuration にする。
# ADR-0007: キーは <service>/<app>/<env>/terraform.tfstate。
#
# 共通ワークフロー（platform-cicd の terraform-plan action）が
# 次の形で init する:
#
#   terraform init \
#     -backend-config="bucket=${TFSTATE_BUCKET}" \
#     -backend-config="key=serviceA/appA/${ENV}/terraform.tfstate" \
#     -backend-config="region=${AWS_REGION}"
#
# デプロイロールのIAMは */*/<env>/* で絞っているため、
# この3階層のキー構造は必須。

terraform {
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
