import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'app.lovable.29f66e6029e94958ab2e41e8e4bfbcc4',
  appName: 'society-guard-buddy',
  webDir: 'dist',
  server: {
    url: 'https://29f66e60-29e9-4958-ab2e-41e8e4bfbcc4.lovableproject.com?forceHideBadge=true',
    cleartext: true,
  },
  android: {
    // FLAG_SECURE is set in MainActivity.java after running `npx cap add android`
    // Add to android/app/src/main/java/.../MainActivity.java:
    // import android.view.WindowManager;
    // @Override protected void onCreate(Bundle savedInstanceState) {
    //   super.onCreate(savedInstanceState);
    //   getWindow().setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE);
    // }
  },
  plugins: {
    SplashScreen: {
      launchAutoHide: true,
      androidScaleType: 'CENTER_CROP',
    },
  },
};

export default config;
