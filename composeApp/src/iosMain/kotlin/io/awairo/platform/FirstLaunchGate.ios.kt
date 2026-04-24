package io.awairo.platform

class IosFirstLaunchGate : FirstLaunchGate {
    override fun shouldShowOnboarding(): Boolean = false
    override fun markOnboardingCompleted() = Unit
}
