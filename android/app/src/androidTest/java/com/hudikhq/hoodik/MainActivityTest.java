package com.hudikhq.hoodik;

import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

// Patrol's Android entrypoint. The body is lifted directly from Patrol's own
// example at packages/patrol/example/android/app/src/androidTest/... — the
// parameterised-runner pattern is required for Patrol to enumerate Dart
// tests up-front so each one surfaces as its own JUnit result in
// `adb shell am instrument` output. Keep this file Java (not Kotlin) to
// match upstream; mixing in Kotlin here breaks parameterised JUnit when the
// Gradle Kotlin compile order changes.
@RunWith(Parameterized.class)
public class MainActivityTest {
    @Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation =
            (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    private final String dartTestName;

    @Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation =
            (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.runDartTest(dartTestName);
    }
}
