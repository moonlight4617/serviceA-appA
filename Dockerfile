# ADR-0005: 環境に依存しないイメージを1つだけ作る。
#
# このイメージには環境ごとの値を一切焼き込まない。
# 接続先・ログレベル・プロファイルはすべてECSタスク定義の環境変数から注入される。
# そのため同じdigestを dev → stage → prod へ昇格させられる。
#
# jarはCIでビルドしたものを受け取る（マルチステージにすると
# CIのGradleキャッシュが効かず、ビルド時間が伸びる）。

FROM eclipse-temurin:21-jre-alpine

# 非rootで動かす。ADR-0013によりタスクはパブリックサブネットに置くため、
# コンテナ側の権限も最小にしておく
RUN addgroup -S app && adduser -S -G app app

WORKDIR /app

ARG JAR_FILE=build/libs/app.jar
COPY --chown=app:app ${JAR_FILE} /app/app.jar

USER app

EXPOSE 8080

# コンテナ内のヘルスチェックは設定しない。
# ALBのターゲットグループが /actuator/health を叩くため二重になる

# JVMにコンテナのCPU・メモリ制限を認識させる
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -XX:+UseContainerSupport"

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
