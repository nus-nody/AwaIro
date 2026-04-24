package io.awairo.data.local

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver
import io.awairo.db.AwaIroDatabase

actual class DatabaseFactory {
    actual fun createDriver(): SqlDriver =
        NativeSqliteDriver(AwaIroDatabase.Schema, "awairo.db")
}
