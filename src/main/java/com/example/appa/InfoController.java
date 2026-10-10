package com.example.appa;

import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 動作確認用のエンドポイント。
 *
 * <p>ADR-0005の検証を目的としている。1つのjarを3環境で昇格させる構成が
 * 実際に成立しているかを、デプロイ後にここで確認できる。
 *
 * <ul>
 *   <li>activeProfiles: 実行時に選ばれたプロファイル。ビルド時ではない
 *   <li>environmentLabel: application-&lt;env&gt;.yml から読まれた値
 *   <li>commitSha: ECSタスク定義の環境変数として注入されたcommit SHA
 *   <li>contextPath: ALBのパス振り分け（ADR-0013）に対応するための接頭辞
 * </ul>
 *
 * <p>同じcommitSha・同じイメージdigestで、environmentLabel だけが環境ごとに
 * 変わっていれば「1回ビルドして昇格」が成立している。
 */
@RestController
public class InfoController {

    private final Environment environment;

    private final String environmentLabel;

    private final String commitSha;

    private final String contextPath;

    public InfoController(
            Environment environment,
            @Value("${app.environment-label:unknown}") String environmentLabel,
            @Value("${app.commit-sha:unknown}") String commitSha,
            @Value("${server.servlet.context-path:}") String contextPath) {
        this.environment = environment;
        this.environmentLabel = environmentLabel;
        this.commitSha = commitSha;
        this.contextPath = contextPath;
    }

    @GetMapping("/")
    public Map<String, Object> info() {
        return Map.of(
                "app", "appA",
                "service", "serviceA",
                "activeProfiles", environment.getActiveProfiles(),
                "environmentLabel", environmentLabel,
                "commitSha", commitSha,
                "contextPath", contextPath);
    }
}
