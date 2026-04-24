package io.awairo.platform

interface FirstLaunchGate {
    fun shouldShowOnboarding(): Boolean
    fun markOnboardingCompleted()
}
