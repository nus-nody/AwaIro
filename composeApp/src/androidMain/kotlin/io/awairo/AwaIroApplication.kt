package io.awairo

import android.app.Application
import io.awairo.di.androidModule
import io.awairo.di.appModule
import org.koin.android.ext.koin.androidContext
import org.koin.core.context.startKoin

class AwaIroApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin {
            androidContext(this@AwaIroApplication)
            modules(androidModule(), appModule())
        }
    }
}
