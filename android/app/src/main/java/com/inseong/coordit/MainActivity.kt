package com.inseong.coordit

import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import com.inseong.coordit.auth.GoogleIdentity
import com.inseong.coordit.ui.app.AppViewModel
import com.inseong.coordit.ui.app.CoorditApp
import com.inseong.coordit.ui.threadcharge.GoogleRewardedAdGateway
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) WindowInsetsControllerCompat(window, window.decorView).hide(WindowInsetsCompat.Type.systemBars())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
        val container = (application as CoorditApplication).container
        val model = ViewModelProvider(this, object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T =
                AppViewModel(container.repository, container.welcome, container.homeRepository, GoogleRewardedAdGateway(applicationContext)) as T
        })[AppViewModel::class.java]
        val closet = ViewModelProvider(this, object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T =
                com.inseong.coordit.ui.closet.ClosetViewModel(container.closetRepository, container.repository) as T
        })[com.inseong.coordit.ui.closet.ClosetViewModel::class.java]
        val fitLab = ViewModelProvider(this, object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T =
                com.inseong.coordit.ui.fitlab.FitLabViewModel(container.fitLabRepository, container.repository, container.fitLabHistory, container.fitLabSubmission) as T
        })[com.inseong.coordit.ui.fitlab.FitLabViewModel::class.java]
        val identity = GoogleIdentity(applicationContext)
        val reduceMotion = Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
        setContent {
            CoorditApp(model, reduceMotion,
                onGoogle = {
                    val attempt = model.beginGoogle()
                    if (attempt != null) lifecycleScope.launch {
                        try {
                            val credential = identity.signIn(this@MainActivity)
                            if (credential == null) model.googleCanceled(attempt) else model.googleCredential(attempt, credential)
                        } catch (error: CancellationException) {
                            model.googleCanceled(attempt)
                            throw error
                        } catch (error: Exception) { model.googleFailed(attempt, error) }
                    }
                },
                onLogout = { model.logout { identity.clear() } },
                onDeleteAccount = { model.deleteAccount { identity.clear() } },
                closetModel = closet,
                fitLabModel = fitLab,
            )
        }
    }
}
