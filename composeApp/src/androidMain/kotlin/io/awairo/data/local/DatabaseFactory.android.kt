package io.awairo.data.local

import android.content.Context
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.android.AndroidSqliteDriver
import io.awairo.db.AwaIroDatabase

actual class DatabaseFactory(private val context: Context) {
    actual fun createDriver(): SqlDriver =
        AndroidSqliteDriver(AwaIroDatabase.Schema, context, "awairo.db")
}
