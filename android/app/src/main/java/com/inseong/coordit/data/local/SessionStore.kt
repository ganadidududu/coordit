package com.inseong.coordit.data.local

import com.inseong.coordit.data.model.AuthSession

interface SessionStore {
    suspend fun read(): AuthSession?
    suspend fun write(session: AuthSession)
    suspend fun clear()
}
