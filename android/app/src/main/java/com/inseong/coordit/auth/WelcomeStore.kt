package com.inseong.coordit.auth

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException

interface WelcomeStore {
    fun hasCompleted(): Boolean
    suspend fun markCompleted()
}

class DeviceWelcomeStore(context: Context) : WelcomeStore {
    private val preferences = context.applicationContext.getSharedPreferences("coordit-welcome", Context.MODE_PRIVATE)
    override fun hasCompleted() = preferences.getBoolean("completed", false)
    override suspend fun markCompleted() = withContext(Dispatchers.IO) {
        if (!preferences.edit().putBoolean("completed", true).commit()) throw IOException("Welcome preference could not be saved")
    }
}
