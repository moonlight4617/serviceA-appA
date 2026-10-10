# serviceA-appA

共通CI/CD基盤に乗せるサンプルアプリ（Java / Spring Boot / ECS Fargate）。

このリポジトリは**実装としてはほぼ空**で、CI/CDの処理は
[platform-cicd](../platform-cicd/) にある。アプリ側が持つのは次の2つだけ（ADR-0001）。

- `.platform/app.yaml` — 宣言
- `.github/workflows/*.yml` — 共通ワークフローを呼ぶ数行

## このアプリが検証しているもの

### ADR-0005「1回だけビルドして昇格」が実際に成立するか

Spring Profileは**実行時**に選択されるため、1つのjarに全環境の設定を同梱できる。

```
build/libs/app.jar
  ├── application.yml
  ├── application-dev.yml
  ├── application-stage.yml
  └── application-prod.yml
```

環境の切り替えはECSタスク定義の環境変数で行う。

| 環境変数 | 役割 |
|---|---|
| `SPRING_PROFILES_ACTIVE` | プロファイルの選択 |
| `SERVER_SERVLET_CONTEXT_PATH` | ALBのパス接頭辞（ADR-0013） |
| `APP_COMMIT_SHA` | 稼働中のアプリが自分の出自を答えるため |

デプロイ後に `GET /{env}/appA/` を叩くと確認できる。

```json
{
  "app": "appA",
  "activeProfiles": ["prod"],
  "environmentLabel": "prod",
  "commitSha": "a1b2c3d...",
  "contextPath": "/prod/appA"
}
```

**同じ `commitSha`・同じイメージdigestで `environmentLabel` だけが変われば、
「1回ビルドして昇格」が成立している。**

### ADR-0013「ALB 1台をパスで振り分ける」の副作用

ALBはパスを書き換えられないため、**アプリ側が自分のパス接頭辞を知る必要がある。**
本来アプリはデプロイ先のパス構造を知るべきではない。
これは実験構成のための不自然さであり、実務でホスト名振り分けに移行すれば不要になる。

## 構成

```
serviceA-appA/
├── .platform/
│   ├── app.yaml                     共通CI/CDへの宣言
│   └── security-exceptions.yaml     脆弱性の抑制（空）
├── .github/workflows/
│   ├── ci.yml                       共通CIを呼ぶだけ
│   └── collect-logs.yml             ログのS3格納を呼ぶだけ
├── build.gradle.kts                 SpotBugsのSARIF出力を有効化（規約）
├── Dockerfile                       環境に依存しないイメージ
├── src/
│   ├── main/java/com/example/appa/  アプリ本体
│   ├── main/resources/              application.yml + プロファイル別
│   └── test/java/                   ADR-0005の前提を検証するテスト
└── terraform/
    ├── data.tf                      SSMから共通資材を読む（ADR-0014）
    ├── iam.tf                       タスクロール（/platform/<env>/ パス配下）
    ├── main.tf                      ロググループ / TG / ルール / タスク定義 / サービス
    └── env/{dev,stage,prod}.tfvars  環境別の値
```

## ローカルでの実行

```bash
# Gradle Wrapper を一度生成する（バージョン固定のため推奨）
gradle wrapper

./gradlew bootRun --args='--spring.profiles.active=local'
curl http://localhost:8080/
```

## デプロイ

CI/CDから行う。手動でapplyする場合は次のとおり。

```bash
cd terraform
terraform init \
  -backend-config="bucket=${TFSTATE_BUCKET}" \
  -backend-config="key=serviceA/appA/dev/terraform.tfstate" \
  -backend-config="region=ap-northeast-1"

terraform apply \
  -var-file=env/dev.tfvars \
  -var="image_digest=sha256:..." \
  -var="commit_sha=$(git rev-parse HEAD)"
```

`stage` / `prod` では `image_digest` が**必須**（変数のvalidationで強制）。
ADR-0005により、検証済みの成果物をdigestで指定する必要がある。

## このアプリがプラットフォームの規約に従っている箇所

| 規約 | 該当箇所 | 守らないとどうなるか |
|---|---|---|
| リソース名を `<service>-<app>-<env>` にする | `terraform/data.tf` の `local.name` | IAMの名前パターンに外れて apply が AccessDenied |
| 全リソースに `Environment` タグ | `terraform/versions.tf` の `default_tags` | IAMのタグ条件に外れて apply が失敗 |
| IAMロールを `/platform/<env>/` に作る | `terraform/iam.tf` の `path` | 同上 |
| ALBの優先度はSSMの値を使う | `terraform/data.tf` の `listener_rule_priority` | 3環境で優先度が衝突して apply が失敗 |
| SpotBugsのSARIF出力 | `build.gradle.kts` | CIのスキャンジョブが失敗 |
| 環境別の値は `env/<env>.tfvars` | `terraform/env/` | — |

## 未確認の項目

| 内容 | 状況 |
|---|---|
| Gradleビルドが通るか | **未検証**。ローカルにJava/Gradleがなく、Dockerデーモンも停止していたため確認できていない。Spring Boot 4.1.1 と SpotBugs 6.5.12 はリポジトリ上の存在のみ確認済み |
| Gradle Wrapper | **未同梱**。`gradle wrapper` で生成する必要がある。CIは環境のgradleにフォールバックする |
| Dockerイメージのビルド | 未検証 |
| ECSへの実デプロイ | 未実施（`platform-infra` のapply前） |

## 構築済みの環境（2026-10-11）

`platform-infra` をapply済み。共通ALBのパス振り分けは次のとおり。

| 環境 | URL |
|---|---|
| dev | `http://<ALBのDNS名>/dev/appA` |
| stage | `http://<ALBのDNS名>/stage/appA` |
| prod | `http://<ALBのDNS名>/prod/appA` |

ALBのDNS名はSSM Parameter Store `/platform/<env>/alb_dns_name` から取得できる
（ADR-0002によりリポジトリには記載しない）。
