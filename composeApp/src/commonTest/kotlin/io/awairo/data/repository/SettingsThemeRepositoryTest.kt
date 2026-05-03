package io.awairo.data.repository

import com.russhwolf.settings.MapSettings
import io.awairo.domain.model.SkyPalette
import io.awairo.domain.model.ThemeMode
import kotlin.test.Test
import kotlin.test.assertEquals

class SettingsThemeRepositoryTest {

    @Test
    fun returnsSystemAndNightSky_whenSettingsAreEmpty() {
        val repo = SettingsThemeRepository(MapSettings())
        assertEquals(ThemeMode.SYSTEM, repo.observeThemeMode().value)
        assertEquals(SkyPalette.NIGHT_SKY, repo.observeSkyPalette().value)
    }

    @Test
    fun returnsStoredValues_whenSettingsContainValidEnumNames() {
        val settings = MapSettings(
            "theme_mode" to "DARK",
            "sky_palette" to "DUSK",
        )
        val repo = SettingsThemeRepository(settings)
        assertEquals(ThemeMode.DARK, repo.observeThemeMode().value)
        assertEquals(SkyPalette.DUSK, repo.observeSkyPalette().value)
    }

    @Test
    fun fallsBackToDefaults_whenStoredValuesAreInvalid() {
        val settings = MapSettings(
            "theme_mode" to "NOT_A_REAL_MODE",
            "sky_palette" to "GIBBERISH",
        )
        val repo = SettingsThemeRepository(settings)
        assertEquals(ThemeMode.SYSTEM, repo.observeThemeMode().value)
        assertEquals(SkyPalette.NIGHT_SKY, repo.observeSkyPalette().value)
    }

    @Test
    fun setThemeMode_updatesStateFlowAndPersists() {
        val settings = MapSettings()
        val repo = SettingsThemeRepository(settings)

        repo.setThemeMode(ThemeMode.LIGHT)

        assertEquals(ThemeMode.LIGHT, repo.observeThemeMode().value)
        assertEquals("LIGHT", settings.getStringOrNull("theme_mode"))
    }

    @Test
    fun setSkyPalette_updatesStateFlowAndPersists() {
        val settings = MapSettings()
        val repo = SettingsThemeRepository(settings)

        repo.setSkyPalette(SkyPalette.AKATSUKI)

        assertEquals(SkyPalette.AKATSUKI, repo.observeSkyPalette().value)
        assertEquals("AKATSUKI", settings.getStringOrNull("sky_palette"))
    }

    @Test
    fun roundTrip_persistsAcrossRepositoryInstances() {
        val settings = MapSettings()
        SettingsThemeRepository(settings).setSkyPalette(SkyPalette.MIST)

        val freshRepo = SettingsThemeRepository(settings)

        assertEquals(SkyPalette.MIST, freshRepo.observeSkyPalette().value)
    }
}
