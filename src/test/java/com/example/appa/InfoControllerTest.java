package com.example.appa;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;
import org.springframework.test.context.ActiveProfiles;

/**
 * ADR-0005の前提を検証するテスト。
 *
 * <p>「1つの成果物でプロファイルを切り替えるだけで環境ごとの値が変わる」ことを
 * 確認する。ここが壊れていると、環境別ビルドに戻さざるを得なくなる。
 *
 * <p>MockMvcを使わないのは、Spring Boot 4で
 * {@code org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc}
 * のパッケージが移動したため。このテストの目的は「実行時にプロファイルが選択され、
 * application-&lt;env&gt;.yml の値が反映されること」の確認であり、
 * HTTPの経路までは検証しなくてよい。
 * ALB経由の疎通はデプロイ後に実環境で確認する。
 */
@SpringBootTest
@ActiveProfiles("stage")
class InfoControllerTest {

    @Autowired
    private InfoController controller;

    @Autowired
    private Environment environment;

    @Test
    void プロファイルは実行時に選択される() {
        // ビルド時に固定された値ではなく、@ActiveProfiles で選ばれた値が反映される
        assertThat(environment.getActiveProfiles()).containsExactly("stage");
    }

    @Test
    void 環境ごとの設定が実行時に注入される() {
        Map<String, Object> info = controller.info();

        assertThat(info.get("app")).isEqualTo("appA");
        assertThat(info.get("service")).isEqualTo("serviceA");

        // application-stage.yml の app.environment-label が反映されている。
        // 同じjarで application-prod.yml を選べば prod になる。
        // これが成立していれば「1回ビルドして昇格」が可能である
        assertThat(info.get("environmentLabel")).isEqualTo("stage");
    }
}
