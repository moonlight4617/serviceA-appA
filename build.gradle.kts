// ADR-0005の検証対象:
//   環境ごとにビルドを分けず、1つのjarに全プロファイルの設定を同梱する。
//   環境の切り替えは実行時（SPRING_PROFILES_ACTIVE）に行う。
//
//   -Pprofile=prod のようにビルドを環境ごとに分ける構成にはしない。
//   分けると「stageで確認したバイナリとprodに出るバイナリが別物」になる。

plugins {
    java

    // 現行の安定版を使う。古いバージョンを使うと既知のCVEにより
    // 自分自身のセキュリティゲート（ADR-0008）で止まる
    id("org.springframework.boot") version "4.1.1"
    id("io.spring.dependency-management") version "1.1.7"

    // 共通CI/CDの規約: SpotBugsのSARIF出力を有効にすること。
    // 判定はSARIFのみを読む（ADR-0008）
    id("com.github.spotbugs") version "6.5.12"
}

group = "com.example"
version = "0.1.0"

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")

    // ALBのヘルスチェック先として /actuator/health を使う
    implementation("org.springframework.boot:spring-boot-starter-actuator")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

// 成果物の名前を固定する。Dockerfileがバージョン番号に依存しないようにするため
tasks.bootJar {
    archiveFileName.set("app.jar")
}

spotbugs {
    // 検出があってもビルドは失敗させない。停止の判断はゲートが行う（ADR-0008）。
    // ここで失敗させると、ゲートの基準とビルドの基準が二重管理になる
    ignoreFailures.set(true)
}

tasks.spotbugsMain {
    reports.create("sarif") {
        required.set(true)
        outputLocation.set(layout.buildDirectory.file("reports/spotbugs/main.sarif"))
    }
    // XMLとHTMLは使わない。SARIFに統一する
    reports.named("xml") { required.set(false) }
}
