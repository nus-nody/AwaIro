package io.awairo.platform

interface ShareService {
    suspend fun shareImage(imagePath: String, caption: String)
    suspend fun saveToGallery(imagePath: String)
}
