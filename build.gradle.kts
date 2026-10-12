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

// セキュリティゲート（ADR-0008）が検出した脆弱性への対応。
// 抑制ではなく実際にバージョンを上げる。
// 修正版が提供されている脆弱性は抑制の対象にすべきではない。
//
// 上書きは io.spring.dependency-management プラグインが読む
// BOMのプロパティ名で行う必要がある。
// Gradleの dependencies { constraints { ... } } では効かない
// （BOMのバージョン管理が優先されるため）。
//
// プロパティ名は spring-boot-dependencies の pom で確認できる:
//   https://repo1.maven.org/maven2/org/springframework/boot/spring-boot-dependencies/<ver>/
//
// 埋め込みTomcat: CVE-2026-65182 / 65905 / 68525（BOMの既定 11.0.24）
extra["tomcat.version"] = "11.0.25"

// Jackson: CVE-2026-68497 / 89407 / 89425 / 91776 / 91777（BOMの既定 3.1.5）
extra["jackson-bom.version"] = "3.1.7"

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
    // SpotBugs 6.x では既定のレポートが登録されていないため、
    // reports.named("xml") を参照すると「SpotBugsReport with name 'xml' not found」で
    // タスクの生成自体に失敗する。SARIFだけを作成する（ADR-0008: 判定はSARIFのみ）
    reports.create("sarif") {
        required.set(true)
        outputLocation.set(layout.buildDirectory.file("reports/spotbugs/main.sarif"))
    }
}
