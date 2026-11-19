package dev.cuttlefish.example;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.os.Build;
import android.widget.TextView;

import androidx.test.core.app.ActivityScenario;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class ExampleInstrumentedTest {
    @Test
    public void targetContextHasApplicationId() {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        assertEquals("dev.cuttlefish.example", context.getPackageName());
    }

    @Test
    public void runsOnCuttlefish() {
        String hardware = Build.HARDWARE + " " + Build.DEVICE + " " + Build.MODEL;
        assertTrue("unexpected device: " + hardware,
                hardware.toLowerCase().contains("cutf") || hardware.toLowerCase().contains("cuttlefish"));
    }

    @Test
    public void activityShowsGreeting() {
        try (ActivityScenario<MainActivity> scenario = ActivityScenario.launch(MainActivity.class)) {
            scenario.onActivity(activity -> {
                TextView view = activity.findViewById(MainActivity.GREETING_ID);
                assertEquals(Greeter.greet(Build.MODEL), view.getText().toString());
            });
        }
    }
}
