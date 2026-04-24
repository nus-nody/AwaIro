package io.awairo.domain.model

import kotlinx.datetime.Instant

data class Photo(
    val id: String,
    val capturedAt: Instant,
    val developedAt: Instant,
    val imagePath: String,
    val memo: String,
    val areaLabel: String
) {
    fun isDeveloped(now: Instant): Boolean = now >= developedAt
}
