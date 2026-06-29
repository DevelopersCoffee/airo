package io.airo.app;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;

import com.ryanheise.audioservice.AudioServiceActivity;
import java.lang.reflect.Method;
import java.util.Arrays;
import org.junit.Test;

public class MainActivityStartupContractTest {
    @Test
    public void mainActivityUsesAudioServiceActivityBaseClass() {
        assertEquals(AudioServiceActivity.class, MainActivity.class.getSuperclass());
    }

    @Test
    public void mainActivityDoesNotOverrideCachedEngineLookup() {
        boolean overridesCachedEngineId =
                Arrays.stream(MainActivity.class.getDeclaredMethods())
                        .map(Method::getName)
                        .anyMatch("getCachedEngineId"::equals);

        assertFalse(
                "MainActivity must not hardcode a cached Flutter engine id on cold start.",
                overridesCachedEngineId);
    }
}
