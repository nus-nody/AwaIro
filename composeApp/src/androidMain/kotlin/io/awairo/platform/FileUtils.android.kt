package io.awairo.platform

import java.io.File

actual fun deletePhotoFile(absolutePath: String) {
    File(absolutePath).delete()
}
