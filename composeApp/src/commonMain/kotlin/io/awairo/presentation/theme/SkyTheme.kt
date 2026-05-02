package io.awairo.presentation.theme

import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import io.awairo.domain.model.SkyPalette
import io.awairo.domain.model.ThemeMode

data class SkyTheme(
    val palette: SkyPalette,
    val mode: ThemeMode,
    val isDark: Boolean,
    val backgroundTop: Color,
    val backgroundBottom: Color,
    val gradientA: Color,
    val gradientB: Color,
    val gradientC: Color,
    val textPrimary: Color,
    val textSecondary: Color,
)

val LocalSkyTheme = compositionLocalOf<SkyTheme> {
    error("SkyTheme not provided. Wrap your composable in CompositionLocalProvider(LocalSkyTheme provides ...)")
}

/**
 * 現在のパレット・ダークモードフラグから [SkyTheme] を解決する。
 */
fun resolveSkyTheme(palette: SkyPalette, mode: ThemeMode, isSystemDark: Boolean): SkyTheme {
    val dark = when (mode) {
        ThemeMode.SYSTEM -> isSystemDark
        ThemeMode.DARK -> true
        ThemeMode.LIGHT -> false
    }
    val colors = if (dark) darkColorsFor(palette) else lightColorsFor(palette)
    return SkyTheme(
        palette = palette,
        mode = mode,
        isDark = dark,
        backgroundTop = colors.bgTop,
        backgroundBottom = colors.bgBottom,
        gradientA = colors.gradA,
        gradientB = colors.gradB,
        gradientC = colors.gradC,
        textPrimary = colors.textPrimary,
        textSecondary = colors.textSecondary,
    )
}

private data class PaletteColors(
    val bgTop: Color, val bgBottom: Color,
    val gradA: Color, val gradB: Color, val gradC: Color,
    val textPrimary: Color, val textSecondary: Color,
)

private fun darkColorsFor(p: SkyPalette): PaletteColors = when (p) {
    SkyPalette.NIGHT_SKY -> PaletteColors(
        Color(0xFF03030E), Color(0xFF06061A),
        Color(0xD9190837), Color(0xCC081437), Color(0x8C041E16),
        Color(0xCCFFFFFF), Color(0x80FFFFFF)
    )
    SkyPalette.MIST -> PaletteColors(
        Color(0xFF070C12), Color(0xFF0A1220),
        Color(0xD908193C), Color(0xCC052832), Color(0x8C031E2D),
        Color(0xCCFFFFFF), Color(0x80FFFFFF)
    )
    SkyPalette.DUSK -> PaletteColors(
        Color(0xFF0E0608), Color(0xFF1C0A0A),
        Color(0xD9370C08), Color(0xCC280F05), Color(0x8C0A061E),
        Color(0xCCFFFFFF), Color(0x80FFFFFF)
    )
    SkyPalette.KOMOREBI -> PaletteColors(
        Color(0xFF040C06), Color(0xFF061410),
        Color(0xD9062312), Color(0xCC08321E), Color(0x801E2808),
        Color(0xCCFFFFFF), Color(0x80FFFFFF)
    )
    SkyPalette.AKATSUKI -> PaletteColors(
        Color(0xFF0A0608), Color(0xFF180A14),
        Color(0xD9320828), Color(0xCC0C0837), Color(0x8C18081E),
        Color(0xCCFFFFFF), Color(0x80FFFFFF)
    )
    SkyPalette.SILVER_FOG -> PaletteColors(
        Color(0xFF080A10), Color(0xFF10121E),
        Color(0xD9141932), Color(0xCC1E233C), Color(0x8C12172A),
        Color(0xCCFFFFFF), Color(0x80FFFFFF)
    )
}

private fun lightColorsFor(p: SkyPalette): PaletteColors = when (p) {
    SkyPalette.NIGHT_SKY -> PaletteColors(
        Color(0xFFECEAF4), Color(0xFFDDDAF0),
        Color(0x40A08CDC), Color(0x338CA0E6), Color(0x00000000),
        Color(0xCC000000), Color(0x80000000)
    )
    SkyPalette.MIST -> PaletteColors(
        Color(0xFFEAF0F4), Color(0xFFD8E8F0),
        Color(0x478CB4D2), Color(0x38A0C8DC), Color(0x00000000),
        Color(0xCC000000), Color(0x80000000)
    )
    SkyPalette.DUSK -> PaletteColors(
        Color(0xFFF8EDE4), Color(0xFFF0DDD0),
        Color(0x52F0A064), Color(0x38DC7850), Color(0x29B464A0),
        Color(0xCC000000), Color(0x80000000)
    )
    SkyPalette.KOMOREBI -> PaletteColors(
        Color(0xFFEEF4E8), Color(0xFFE0ECDA),
        Color(0x478CC864), Color(0x38B4DC78), Color(0x2EDCC850),
        Color(0xCC000000), Color(0x80000000)
    )
    SkyPalette.AKATSUKI -> PaletteColors(
        Color(0xFFF8EAF0), Color(0xFFF0D8E8),
        Color(0x47DC8CB4), Color(0x33B48CDC), Color(0x00000000),
        Color(0xCC000000), Color(0x80000000)
    )
    SkyPalette.SILVER_FOG -> PaletteColors(
        Color(0xFFEEEFF4), Color(0xFFE0E2EC),
        Color(0x4DB4B9D2), Color(0x38A0A5C8), Color(0x00000000),
        Color(0xCC000000), Color(0x80000000)
    )
}
