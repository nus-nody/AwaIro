package io.awairo.domain.model

import kotlinx.datetime.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlin.time.Duration
import kotlin.time.Duration.Companion.hours

class PhotoTest {

    private fun makePhoto(capturedAt: Instant, developedAt: Instant) = Photo(
        id = "test",
        capturedAt = capturedAt,
        developedAt = developedAt,
        imagePath = "/tmp/test.jpg",
        memo = "",
        areaLabel = "test"
    )

    @Test
    fun isDeveloped_returnsTrue_whenNowIsAfterDevelopedAt() {
        val photo = makePhoto(
            capturedAt = Instant.parse("2026-05-02T00:00:00Z"),
            developedAt = Instant.parse("2026-05-03T00:00:00Z")
        )
        val now = Instant.parse("2026-05-03T00:00:01Z")
        assertTrue(photo.isDeveloped(now))
    }

    @Test
    fun isDeveloped_returnsTrue_atExactBoundary() {
        val developedAt = Instant.parse("2026-05-03T00:00:00Z")
        val photo = makePhoto(
            capturedAt = Instant.parse("2026-05-02T00:00:00Z"),
            developedAt = developedAt
        )
        assertTrue(photo.isDeveloped(developedAt))
    }

    @Test
    fun isDeveloped_returnsFalse_whenNowIsBeforeDevelopedAt() {
        val photo = makePhoto(
            capturedAt = Instant.parse("2026-05-02T00:00:00Z"),
            developedAt = Instant.parse("2026-05-03T00:00:00Z")
        )
        val now = Instant.parse("2026-05-02T23:59:59Z")
        assertFalse(photo.isDeveloped(now))
    }

    @Test
    fun remainingUntilDeveloped_returnsZero_whenAlreadyDeveloped() {
        val photo = makePhoto(
            capturedAt = Instant.parse("2026-05-02T00:00:00Z"),
            developedAt = Instant.parse("2026-05-03T00:00:00Z")
        )
        val now = Instant.parse("2026-05-04T00:00:00Z")
        assertEquals(Duration.ZERO, photo.remainingUntilDeveloped(now))
    }

    @Test
    fun remainingUntilDeveloped_returnsCorrectDuration_whenNotDeveloped() {
        val photo = makePhoto(
            capturedAt = Instant.parse("2026-05-02T00:00:00Z"),
            developedAt = Instant.parse("2026-05-03T00:00:00Z")
        )
        val now = Instant.parse("2026-05-02T18:00:00Z")
        assertEquals(6.hours, photo.remainingUntilDeveloped(now))
    }

    @Test
    fun remainingUntilDeveloped_returnsZero_atExactBoundary() {
        val developedAt = Instant.parse("2026-05-03T00:00:00Z")
        val photo = makePhoto(
            capturedAt = Instant.parse("2026-05-02T00:00:00Z"),
            developedAt = developedAt
        )
        assertEquals(Duration.ZERO, photo.remainingUntilDeveloped(developedAt))
    }
}
