package io.awairo.domain.usecase

import io.awairo.domain.model.Photo
import io.awairo.domain.repository.PhotoRepository
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlin.time.Duration
import kotlin.time.Duration.Companion.hours

private class FakeClock(private val instant: Instant) : Clock {
    override fun now(): Instant = instant
}

private class FakePhotoRepository(private val photos: List<Photo>) : PhotoRepository {
    override suspend fun save(photo: Photo) = error("not used")
    override suspend fun findById(id: String): Photo? = error("not used")
    override suspend fun findByLocalDate(date: LocalDate): List<Photo> = error("not used")
    override suspend fun findDevelopedAsOf(now: Instant): List<Photo> = error("not used")
    override suspend fun delete(id: String) = error("not used")
    override suspend fun findAllOrderByCapturedAtDesc(): List<Photo> = photos
    override suspend fun updateMemo(id: String, memo: String) = error("not used")
}

class DevelopPhotoUseCaseTest {

    private fun photo(id: String, captured: Instant) = Photo(
        id = id,
        capturedAt = captured,
        developedAt = captured.plus(24.hours),
        imagePath = "/tmp/$id.jpg",
        memo = "",
        areaLabel = ""
    )

    @Test
    fun returnsAllPhotosInOrder_withDevelopedFlagsResolved() = runTest {
        val older = photo("a", Instant.parse("2026-05-01T00:00:00Z"))      // 25h前
        val newer = photo("b", Instant.parse("2026-05-02T00:00:00Z"))      // 1h前
        val repo = FakePhotoRepository(listOf(newer, older))
        val now = Instant.parse("2026-05-02T01:00:00Z")
        val useCase = DevelopPhotoUseCase(repo, FakeClock(now))

        val result = useCase()

        assertEquals(2, result.size)
        assertEquals("b", result[0].photo.id)  // 新しい順を維持
        assertFalse(result[0].isDeveloped)     // 1h 前撮影 → 未現像
        assertEquals(23.hours, result[0].remaining)  // 24h - 1h
        assertEquals("a", result[1].photo.id)
        assertTrue(result[1].isDeveloped)      // 25h 前撮影 → 現像済み
        assertEquals(Duration.ZERO, result[1].remaining)
    }

    @Test
    fun emptyList_whenNoPhotos() = runTest {
        val useCase = DevelopPhotoUseCase(
            FakePhotoRepository(emptyList()),
            FakeClock(Instant.parse("2026-05-02T00:00:00Z"))
        )
        assertTrue(useCase().isEmpty())
    }
}
