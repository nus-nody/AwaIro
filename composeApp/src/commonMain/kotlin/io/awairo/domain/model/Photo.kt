package io.awairo.domain.model

import kotlinx.datetime.Instant
import kotlin.time.Duration

data class Photo(
    val id: String,
    val capturedAt: Instant,
    val developedAt: Instant,
    val imagePath: String,
    val memo: String,
    val areaLabel: String
) {
    fun isDeveloped(now: Instant): Boolean = now >= developedAt

    /**
     * 現像までの残り時間。現像済みの場合は [Duration.ZERO]。
     */
    fun remainingUntilDeveloped(now: Instant): Duration =
        if (isDeveloped(now)) Duration.ZERO else developedAt - now
}
