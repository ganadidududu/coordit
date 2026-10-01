package com.inseong.coordit

import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import com.inseong.coordit.preview.FoundationActivity
import org.junit.Rule
import org.junit.Test

class FoundationUiTest {
    @get:Rule
    val compose = createAndroidComposeRule<FoundationActivity>()

    @Test
    fun primaryActionUpdatesStateAndDisabledActionCannotFire() {
        compose.onNodeWithTag("primary-button").performClick()
        compose.onNodeWithTag("press-count").assertTextEquals("클릭 1회")
        compose.onNodeWithTag("disabled-button").assertIsNotEnabled()
        compose.onNodeWithTag("press-count").assertTextEquals("클릭 1회")
    }

    @Test
    fun firstInstallOnlyExposesAuthenticationEntry() {
        compose.onNodeWithTag("toggle-motion").performScrollTo().performClick()
        compose.onNodeWithTag("open-first-install").performScrollTo().performClick()
        compose.onNodeWithTag("splash-signup-entry").assertIsDisplayed().assertHasClickAction()
        compose.onNodeWithTag("splash-signup-entry").performClick()
        compose.onNodeWithTag("last-event").assertTextEquals("로그인 요청 callback")
    }

    @Test
    fun returningSurfaceDispatchesEnterCallback() {
        compose.onNodeWithTag("open-returning").performScrollTo().performClick()
        compose.onNodeWithTag("splash-enter-surface").assertHasClickAction().performClick()
        compose.onNodeWithTag("last-event").assertTextEquals("홈 진입 callback")
    }

    @Test
    fun systemBackReturnsToCatalogWithoutDispatchingCallback() {
        compose.onNodeWithTag("open-first-install").performScrollTo().performClick()
        compose.runOnUiThread { compose.activity.onBackPressedDispatcher.onBackPressed() }
        compose.onNodeWithTag("foundation-catalog").assertIsDisplayed()
        compose.onNodeWithTag("press-count").assertTextEquals("클릭 0회")
        compose.onNodeWithTag("last-event").assertTextEquals("아직 이벤트가 없습니다")
        compose.onNodeWithTag("open-returning").performScrollTo().performClick()
        compose.runOnUiThread { compose.activity.onBackPressedDispatcher.onBackPressed() }
        compose.onNodeWithTag("foundation-catalog").assertIsDisplayed()
        compose.onNodeWithTag("press-count").assertTextEquals("클릭 0회")
        compose.onNodeWithTag("last-event").assertTextEquals("아직 이벤트가 없습니다")
    }

    @Test
    fun activityRecreationKeepsViewModelState() {
        compose.onNodeWithTag("primary-button").performClick()
        compose.activityRule.scenario.recreate()
        compose.onNodeWithTag("press-count").assertTextEquals("클릭 1회")
        compose.onNodeWithTag("last-event").assertTextEquals("기본 버튼 클릭")
    }
}
