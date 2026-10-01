package com.inseong.coordit.preview

import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.LocalOnBackPressedDispatcherOwner
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.NavController
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.inseong.coordit.ui.components.CoorditButton
import com.inseong.coordit.ui.components.CoorditText
import com.inseong.coordit.ui.components.SharedAppBackground
import com.inseong.coordit.ui.screens.SplashPresentation
import com.inseong.coordit.ui.screens.SplashScreen
import com.inseong.coordit.ui.theme.AppColors
import com.inseong.coordit.ui.theme.CoorditTypography

/** Debug-only component host. No production auth bypass, fake backend, or release launcher. */
class FoundationActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
        val start = intent.getStringExtra("route")?.takeIf { it in setOf("catalog", "first-install", "returning") } ?: "catalog"
        val systemReduceMotion = Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
        setContent { FoundationHost(start, intent.getBooleanExtra("reduce_motion", false) || systemReduceMotion) }
    }
}

@Composable
private fun FoundationHost(start: String, systemReduceMotion: Boolean) {
    val model: FoundationViewModel = viewModel()
    val state by model.state.collectAsStateWithLifecycle()
    val nav = rememberNavController()
    val dispatcher = LocalOnBackPressedDispatcherOwner.current?.onBackPressedDispatcher
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(nav, dispatcher, lifecycleOwner) {
        val callback = object : OnBackPressedCallback(nav.previousBackStackEntry != null) {
            override fun handleOnBackPressed() {
                nav.popBackStack()
            }
        }
        val listener = NavController.OnDestinationChangedListener { controller, _, _ ->
            callback.isEnabled = controller.previousBackStackEntry != null
        }
        dispatcher?.addCallback(lifecycleOwner, callback)
        nav.addOnDestinationChangedListener(listener)
        onDispose {
            nav.removeOnDestinationChangedListener(listener)
            callback.remove()
        }
    }
    fun returnToCatalog(event: String) {
        model.record(event)
        if (!nav.popBackStack("catalog", false)) {
            nav.navigate("catalog") { popUpTo(nav.graph.id) { inclusive = true } }
        }
    }
    NavHost(navController = nav, startDestination = start) {
        composable("catalog") {
            FoundationCatalog(
                state = state,
                onPress = { model.record("기본 버튼 클릭") },
                onToggleMotion = model::toggleMotion,
                onPreview = { nav.navigate(it) },
            )
        }
        composable("first-install") {
            SplashScreen(
                presentation = SplashPresentation.FirstInstall,
                onAuthenticationRequested = { returnToCatalog("로그인 요청 callback") },
                onEnter = { returnToCatalog("홈 진입 callback") },
                reduceMotion = state.reduceMotion || systemReduceMotion,
            )
        }
        composable("returning") {
            SplashScreen(
                presentation = SplashPresentation.ReturningUser,
                onAuthenticationRequested = { returnToCatalog("로그인 요청 callback") },
                onEnter = { returnToCatalog("홈 진입 callback") },
                reduceMotion = state.reduceMotion || systemReduceMotion,
            )
        }
    }
}

@Composable
private fun FoundationCatalog(
    state: FoundationState,
    onPress: () -> Unit,
    onToggleMotion: () -> Unit,
    onPreview: (String) -> Unit,
) {
    Box(Modifier.fillMaxSize().testTag("foundation-catalog")) {
        SharedAppBackground(scale = 1f, modifier = Modifier.fillMaxSize())
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 22.dp, vertical = 54.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            CoorditText("COORDIT", CoorditTypography.climate2019(24f).copy(color = Color.White))
            Column(
                Modifier.fillMaxWidth().background(AppColors.panel, RoundedCornerShape(10.dp)).padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                CoorditText("Android Foundation", CoorditTypography.gmarketBold(20f), Modifier.semantics { heading() })
                CoorditText("공통 UI 검증 · DEBUG", CoorditTypography.gmarketMedium(11f).copy(color = AppColors.muted))
                CoorditText("원본 글꼴과 디자인 토큰", CoorditTypography.gmarketMedium(15f))
                CoorditText("가벼운 글꼴 · Gmarket Light", CoorditTypography.gmarketLight(12f))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(AppColors.ink, AppColors.blue, AppColors.cyan, AppColors.green, AppColors.red).forEach { color ->
                        Box(Modifier.size(28.dp).background(color, RoundedCornerShape(6.dp)))
                    }
                }
                CoorditButton("기본 버튼", onPress, Modifier.fillMaxWidth().testTag("primary-button"))
                CoorditButton("비활성화", {}, Modifier.fillMaxWidth().testTag("disabled-button"), enabled = false)
                CoorditText("클릭 ${state.presses}회", CoorditTypography.gmarketMedium(12f), Modifier.testTag("press-count"))
                CoorditText(state.lastEvent, CoorditTypography.gmarketMedium(11f), Modifier.testTag("last-event"))
            }
            CoorditButton("처음 방문 스플래시", { onPreview("first-install") }, Modifier.fillMaxWidth().testTag("open-first-install"), secondary = true)
            CoorditButton("재방문 스플래시", { onPreview("returning") }, Modifier.fillMaxWidth().testTag("open-returning"), secondary = true)
            CoorditButton(
                if (state.reduceMotion) "동작 줄이기: 켜짐" else "동작 줄이기: 꺼짐",
                onToggleMotion,
                Modifier.fillMaxWidth().testTag("toggle-motion"),
                secondary = true,
            )
            CoorditText("이 화면은 개발용 검증 도구입니다.\n로그인·상품 기능을 대신하지 않습니다.", CoorditTypography.gmarketMedium(11f).copy(color = AppColors.muted))
            Spacer(Modifier.height(36.dp))
        }
    }
}
