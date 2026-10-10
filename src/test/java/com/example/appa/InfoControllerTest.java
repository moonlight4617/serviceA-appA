package com.example.appa;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

/**
 * ADR-0005の前提を検証するテスト。
 *
 * <p>「同じ成果物でプロファイルを切り替えるだけで環境ごとの値が変わる」ことを
 * 確認する。ここが壊れていると、環境別ビルドに戻さざるを得なくなる。
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("stage")
class InfoControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void プロファイルは実行時に選択される() throws Exception {
        mockMvc.perform(get("/"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.app").value("appA"))
                // ビルド時に固定された値ではなく、@ActiveProfiles で選ばれた値が返る
                .andExpect(jsonPath("$.environmentLabel").value("stage"))
                .andExpect(jsonPath("$.activeProfiles[0]").value("stage"));
    }

    @Test
    void ヘルスチェックが応答する() throws Exception {
        // ALBのターゲットグループがこのパスを叩く（ADR-0013）
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }
}
