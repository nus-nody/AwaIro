package io.awairo.domain.usecase

import io.awairo.domain.model.Photo
import io.awairo.domain.repository.PhotoRepository
import kotlinx.datetime.Clock
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Duration.Companion.hours

class RecordPhotoUseCase(private val repository: PhotoRepository) {

    sealed class Result {
        data class Success(val photo: Photo) : Result()
        object AlreadyTakenToday : Result()
        data class Error(val cause: Throwable) : Result()
    }

    /**
     * 写真を記録する。
     * @param absoluteImagePath プラットフォームが返した画像の絶対パス（例: "/data/.../photos/abc.jpg"）
     * @param memo ユーザー入力のメモ（空文字可）
     */
    suspend fun execute(absoluteImagePath: String, memo: String): Result {
        return try {
            val now = Clock.System.now()
            val tz = TimeZone.currentSystemDefault()
            val today = now.toLocalDateTime(tz).date

            // 今日の写真が存在するかチェック
            val todayPhotos = repository.findByLocalDate(today)
            if (todayPhotos.isNotEmpty()) {
                return Result.AlreadyTakenToday
            }

            // 絶対パス → 相対パス変換: "/path/to/photos/abc.jpg" → "photos/abc.jpg"
            val filename = absoluteImagePath.substringAfterLast("/")
            val relativePath = "photos/$filename"

            val photo = Photo(
                id = generateId(),
                capturedAt = now,
                developedAt = now.plus(24.hours),
                imagePath = relativePath,
                memo = memo,
                areaLabel = ""
            )
            repository.save(photo)
            Result.Success(photo)
        } catch (e: Throwable) {
            Result.Error(e)
        }
    }

    private fun generateId(): String {
        // KMP compatible UUID generation
        val chars = ('a'..'f') + ('0'..'9')
        fun seg(n: Int) = (1..n).map { chars.random() }.joinToString("")
        return "${seg(8)}-${seg(4)}-${seg(4)}-${seg(4)}-${seg(12)}"
    }
}
