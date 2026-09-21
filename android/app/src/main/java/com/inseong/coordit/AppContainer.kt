package com.inseong.coordit

import android.content.Context
import com.inseong.coordit.data.local.SecureSessionStore
import com.inseong.coordit.data.model.CoorditJson
import com.inseong.coordit.data.remote.CoorditApi
import com.inseong.coordit.data.repository.SessionRepository
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

class AppContainer(context: Context) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .addInterceptor { chain ->
            if (chain.request().url.host == "unconfigured.invalid") throw java.io.IOException("Configure COORDIT_RELEASE_API_BASE_URL before using the backend")
            val scoped = if (chain.request().url.encodedPath.endsWith("/report")) chain.withReadTimeout(180, TimeUnit.SECONDS) else chain
            scoped.proceed(chain.request())
        }
        .build()
    val retrofit: Retrofit = Retrofit.Builder()
        .baseUrl(BuildConfig.API_BASE_URL.trimEnd('/') + "/")
        .client(client)
        .addConverterFactory(GsonConverterFactory.create(CoorditJson.create()))
        .build()
    val api = retrofit.create(CoorditApi::class.java)
    val homeRepository = com.inseong.coordit.data.home.HomeRepository(retrofit.create(com.inseong.coordit.data.home.HomeApi::class.java))
    val closetRepository = com.inseong.coordit.data.closet.ClosetRepository(retrofit.create(com.inseong.coordit.data.closet.ClosetApi::class.java))
    val fitLabRepository = com.inseong.coordit.data.fitlab.FitLabRepository(retrofit.create(com.inseong.coordit.data.fitlab.FitLabApi::class.java))
    val fitLabHistory = com.inseong.coordit.data.fitlab.FitLabHistoryStore(context.applicationContext, com.inseong.coordit.data.model.CoorditJson.create())
    val fitLabSubmission = com.inseong.coordit.data.fitlab.FitLabSubmissionStore(context.applicationContext, com.inseong.coordit.data.model.CoorditJson.create())
    val welcome = com.inseong.coordit.auth.DeviceWelcomeStore(context)
    val repository = SessionRepository(api, SecureSessionStore(context.applicationContext))
}
