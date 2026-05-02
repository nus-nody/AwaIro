package io.awairo

import io.awairo.domain.model.Photo
import io.awairo.domain.repository.PhotoRepository
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Duration.Companion.days
import kotlin.time.Duration.Companion.hours

class FakePhotoRepository : PhotoRepository {
    val savedPhotos = mutableListOf<Photo>()

    override suspend fun save(photo: Photo) {
        savedPhotos.add(photo)
    }

    override suspend fun findById(id: String): Photo? =
        savedPhotos.find { it.id == id }

    override suspend fun findByLocalDate(date: LocalDate): List<Photo> {
        val tz = TimeZone.currentSystemDefault()
        val startOfDay = date.atStartOfDayIn(tz)
        val endOfDay = date.atStartOfDayIn(tz).plus(1.days)
        return savedPhotos.filter {
            it.capturedAt >= startOfDay && it.capturedAt < endOfDay
        }
    }

    override suspend fun findDevelopedAsOf(now: Instant): List<Photo> =
        savedPhotos.filter { it.developedAt <= now }

    override suspend fun delete(id: String) {
        savedPhotos.removeAll { it.id == id }
    }

    override suspend fun findAllOrderByCapturedAtDesc(): List<Photo> =
        savedPhotos.sortedByDescending { it.capturedAt }

    override suspend fun updateMemo(id: String, memo: String) {
        val index = savedPhotos.indexOfFirst { it.id == id }
        if (index >= 0) savedPhotos[index] = savedPhotos[index].copy(memo = memo)
    }

    /** テスト用: 今日の日付の写真を1枚追加する */
    fun addPhotoForToday() {
        val now = kotlinx.datetime.Clock.System.now()
        savedPhotos.add(
            Photo(
                id = "test-id",
                capturedAt = now,
                developedAt = now.plus(24.hours),
                imagePath = "photos/test.jpg",
                memo = "",
                areaLabel = ""
            )
        )
    }
}
