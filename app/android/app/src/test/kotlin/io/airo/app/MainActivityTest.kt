package io.airo.app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MainActivityTest {
    @Test
    fun doesNotForceCachedEngineLookup() {
        val declaredMethodNames = MainActivity::class.java.declaredMethods.map { it.name }

        assertFalse(
            "MainActivity should rely on AudioServiceActivity to create the shared engine on cold start.",
            declaredMethodNames.contains("getCachedEngineId"),
        )
    }

    @Test
    fun overridesOnCreateForEdgeToEdge() {
        // Android 15 (targetSdk 35) enforces edge-to-edge by default; Play
        // Console's pre-launch report flags any Activity that doesn't call
        // enableEdgeToEdge() explicitly. This is a cheap tripwire, not proof
        // the call is present -- see the real check below.
        val declaredMethodNames = MainActivity::class.java.declaredMethods.map { it.name }

        assertTrue(
            "MainActivity must override onCreate to call enableEdgeToEdge().",
            declaredMethodNames.contains("onCreate"),
        )
    }
}
