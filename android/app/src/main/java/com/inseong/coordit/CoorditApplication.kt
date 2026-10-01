package com.inseong.coordit

import android.app.Application

class CoorditApplication : Application() {
    val container by lazy { AppContainer(this) }
}
