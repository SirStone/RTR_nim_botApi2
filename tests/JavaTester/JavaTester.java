import dev.robocode.tankroyale.botapi.*;
import dev.robocode.tankroyale.botapi.events.*;

public class JavaTester extends Bot {

    int direction = 1; // Clockwise or counterclockwise

    public static void main(String[] args) {
        new JavaTester().start();
    }

    JavaTester() {
        super(BotInfo.fromFile("JavaTester.json"));
    }

    @Override
    public void run() {
        while (isRunning()) {
            turnRight(Double.MAX_VALUE * direction);
        }
    }

    @Override
    public void onHitByBullet(HitByBulletEvent event) {
        System.out.println("Ouch, I got hit by a bullet!");
        turnRadarRight(360);
    }
}