package io.airo.app

import org.junit.Assert.assertFalse
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
}
