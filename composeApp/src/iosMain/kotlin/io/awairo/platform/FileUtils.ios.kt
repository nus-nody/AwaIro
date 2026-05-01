package io.awairo.platform

import kotlinx.cinterop.ExperimentalForeignApi
import platform.Foundation.NSFileManager

@OptIn(ExperimentalForeignApi::class)
actual fun deletePhotoFile(absolutePath: String) {
    NSFileManager.defaultManager.removeItemAtPath(absolutePath, error = null)
}
