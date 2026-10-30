package com.inseong.coordit.account

import android.graphics.Bitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.unit.Density
import androidx.test.platform.app.InstrumentationRegistry
import com.inseong.coordit.data.fitlab.*
import com.inseong.coordit.data.home.*
import com.inseong.coordit.preview.AccountPreviewActivity
import com.inseong.coordit.ui.home.HomeScreen
import com.inseong.coordit.ui.home.HomeUiState
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.io.File

class HomeEditorialTest {
    @get:Rule val compose = createAndroidComposeRule<AccountPreviewActivity>()

    @Test fun editorialOpensFitLabAndRecentCardsUseActualSavedHistory() {
        var starts = 0
        var opened: String? = null
        val history = (1..4).map { snapshot(it) }
        compose.setContent { HomeScreen(HomeUiState(), {}, {}, {}, { starts++ }, {}, history, { opened = it.analysisId }, true) }
        capture("home-history")
        compose.onNodeWithText("최근 저장 2개").assertExists()
        compose.onNodeWithTag("coordit-main04-history-card-analysis-1").assertDoesNotExist()
        compose.onNodeWithTag("coordit-main04-history-card-analysis-4").performScrollTo().performClick()
        assertEquals("analysis-4", opened)
        compose.onNodeWithTag("coordit-main04-new-fit-button").performScrollTo().performClick()
        assertEquals(1, starts)
        compose.onNodeWithContentDescription("매거진 2페이지").performClick()
        compose.onNodeWithContentDescription("매거진 2페이지").assertIsSelected()
        capture("home-magazine-second")
    }

    @Test fun homeRemainsUsableWithAccessibilityTextSize() {
        compose.setContent {
            val density = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(density.density, 1.7f)) {
                HomeScreen(HomeUiState(), {}, {}, {}, {}, {}, listOf(snapshot(1), snapshot(2)), reduceMotion = true)
            }
        }
        capture("home-large-text")
        compose.onNodeWithTag("coordit-main04-new-fit-button").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("coordit-main04-history-card-analysis-2").performScrollTo().assertIsDisplayed()
        capture("home-large-text-history")
        compose.onAllNodes(SemanticsMatcher.keyIsDefined(androidx.compose.ui.semantics.SemanticsActions.ScrollBy)).onFirst()
            .performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.ScrollBy) { it(0f, 100_000f) }
        capture("home-large-text-end")
        val viewport = compose.onNodeWithTag("home-scroll").fetchSemanticsNode().boundsInRoot
        assertTrue("Scrolled content must stay below fixed header: $viewport", viewport.top >= viewport.width * .28f)
        compose.onNodeWithTag("coordit-main04-closet-button").assertIsDisplayed()
    }

    private fun snapshot(index: Int): FitLabHistorySnapshot {
        val recommendation = FitLabRecommendation("analysis-$index", "M", 95.0, "잘 맞아요", "기준 옷과 비슷해요.", "high")
        return FitLabHistorySnapshot(analysisId = recommendation.fitAnalysisResultId, userId = "test", savedAt = index.toLong(), productName = "저장한 셔츠 $index", category = "shirt", upper = true, source = FitLabSource.Url, recommendation = recommendation, report = FitLabReportResponse())
    }
    private fun capture(name: String) {
        compose.waitForIdle(); InstrumentationRegistry.getInstrumentation().waitForIdleSync()
        android.os.SystemClock.sleep(700)
        val bitmap = if (compose.onAllNodes(isRoot()).fetchSemanticsNodes().size == 1) {
            compose.onRoot().captureToImage().asAndroidBitmap()
        } else InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        val folder = File(compose.activity.getExternalFilesDir(null), "release-parity").apply { mkdirs() }
        File(folder, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }
}
