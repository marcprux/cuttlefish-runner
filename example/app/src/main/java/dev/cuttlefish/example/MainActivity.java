package dev.cuttlefish.example;

import android.app.Activity;
import android.os.Build;
import android.os.Bundle;
import android.widget.TextView;

public class MainActivity extends Activity {
    static final int GREETING_ID = 0x1001;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        TextView view = new TextView(this);
        view.setId(GREETING_ID);
        view.setText(Greeter.greet(Build.MODEL));
        setContentView(view);
    }
}
