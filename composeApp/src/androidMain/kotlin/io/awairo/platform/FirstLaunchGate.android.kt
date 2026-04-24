package io.awairo.platform

class AndroidFirstLaunchGate : FirstLaunchGate {
    override fun shouldShowOnboarding(): Boolean = false
    override fun markOnboardingCompleted() = Unit
}
