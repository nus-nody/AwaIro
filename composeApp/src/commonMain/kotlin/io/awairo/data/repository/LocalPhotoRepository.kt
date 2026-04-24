package io.awairo.data.repository

import io.awairo.db.AwaIroDatabase
import io.awairo.domain.model.Photo
import io.awairo.domain.repository.PhotoRepository
import kotlinx.datetime.DatePeriod
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.plus

class LocalPhotoRepository(
    private val database: AwaIroDatabase
) : PhotoRepository {

    override suspend fun save(photo: Photo) {
        database.photoQueries.insertPhoto(
            id = photo.id,
            captured_at = photo.capturedAt.toEpochMilliseconds(),
            developed_at = photo.developedAt.toEpochMilliseconds(),
            image_path = photo.imagePath,
            memo = photo.memo,
            area_label = photo.areaLabel
        )
    }

    override suspend fun findById(id: String): Photo? =
        database.photoQueries.selectById(id).executeAsOneOrNull()?.toDomain()

    override suspend fun findByLocalDate(date: LocalDate): List<Photo> {
        val tz = TimeZone.currentSystemDefault()
        val start = date.atStartOfDayIn(tz).toEpochMilliseconds()
        val end = date.plus(DatePeriod(days = 1)).atStartOfDayIn(tz).toEpochMilliseconds()
        return database.photoQueries.selectByDateRange(start, end)
            .executeAsList().map { it.toDomain() }
    }

    override suspend fun findDevelopedAsOf(now: Instant): List<Photo> =
        database.photoQueries.selectDeveloped(now.toEpochMilliseconds())
            .executeAsList().map { it.toDomain() }

    override suspend fun delete(id: String) {
        database.photoQueries.deleteById(id)
    }

    private fun io.awairo.db.Photo.toDomain() = Photo(
        id = id,
        capturedAt = Instant.fromEpochMilliseconds(captured_at),
        developedAt = Instant.fromEpochMilliseconds(developed_at),
        imagePath = image_path,
        memo = memo,
        areaLabel = area_label
    )
}
