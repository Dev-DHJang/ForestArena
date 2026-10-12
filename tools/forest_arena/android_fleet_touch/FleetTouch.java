import android.os.SystemClock;
import android.view.InputDevice;
import android.view.InputEvent;
import android.view.MotionEvent;
import java.lang.reflect.Method;

/** Runs as the normal adb shell user, like Android's input command. */
public final class FleetTouch {
    private static Object manager;
    private static Method inject;
    private static long downTime;
    private static float[] positions;

    private static void send(int action, int count) throws Exception {
        MotionEvent.PointerProperties[] properties = new MotionEvent.PointerProperties[count];
        MotionEvent.PointerCoords[] coords = new MotionEvent.PointerCoords[count];
        for (int i = 0; i < count; i++) {
            properties[i] = new MotionEvent.PointerProperties();
            properties[i].id = i;
            properties[i].toolType = MotionEvent.TOOL_TYPE_FINGER;
            coords[i] = new MotionEvent.PointerCoords();
            coords[i].x = positions[i * 2];
            coords[i].y = positions[i * 2 + 1];
            coords[i].pressure = action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL ? 0 : 1;
            coords[i].size = 1;
        }
        MotionEvent event = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), action, count,
                properties, coords, 0, 0, 1, 1, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0);
        try {
            if (!Boolean.TRUE.equals(inject.invoke(manager, event, 2)))
                throw new IllegalStateException("Android rejected touch injection");
        } finally { event.recycle(); }
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 6) throw new IllegalArgumentException("x1 y1 x2 y2 lead_ms hold_ms required");
        positions = new float[4];
        for (int i = 0; i < 4; i++) {
            positions[i] = Float.parseFloat(args[i]);
            if (!Float.isFinite(positions[i]) || positions[i] < 0)
                throw new IllegalArgumentException("Invalid touch coordinate");
        }
        int lead = Integer.parseInt(args[4]), hold = Integer.parseInt(args[5]);
        if (lead < 80 || lead > 1000 || hold < 40 || hold > 2000)
            throw new IllegalArgumentException("Invalid touch duration");
        Class<?> type;
        try { type = Class.forName("android.hardware.input.InputManagerGlobal"); }
        catch (ClassNotFoundException oldAndroid) { type = Class.forName("android.hardware.input.InputManager"); }
        manager = type.getMethod("getInstance").invoke(null);
        inject = type.getMethod("injectInputEvent", InputEvent.class, int.class);
        downTime = SystemClock.uptimeMillis();
        boolean pressed = false;
        int active = 1;
        try {
            send(MotionEvent.ACTION_DOWN, 1);
            pressed = true;
            SystemClock.sleep(lead);
            active = 2;
            send(MotionEvent.ACTION_POINTER_DOWN | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT), 2);
            SystemClock.sleep(hold);
            send(MotionEvent.ACTION_POINTER_UP | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT), 2);
            active = 1;
            send(MotionEvent.ACTION_UP, 1);
            pressed = false;
            System.out.println("FOREST_ARENA_ADB_MULTI_TOUCH_COMPLETE");
        } finally {
            if (pressed) send(MotionEvent.ACTION_CANCEL, active);
        }
    }
}
