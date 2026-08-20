package com.minhan.hrm.hrm_mobile

import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity

/**
 * Hiện brand splash (logo + chữ + load) ngay khi Activity mở,
 * đè lên khoảng chờ Flutter engine — tránh màn teal trống.
 */
class MainActivity : FlutterActivity() {
  private var brandSplash: View? = null

  override fun onCreate(savedInstanceState: Bundle?) {
    val splashScreen = installSplashScreen()
    super.onCreate(savedInstanceState)

    val overlay = layoutInflater.inflate(R.layout.launch_splash_overlay, null)
    addContentView(
      overlay,
      FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT,
      ),
    )
    brandSplash = overlay

    // Thoát system splash ngay — overlay brand đã phủ.
    splashScreen.setOnExitAnimationListener { provider ->
      provider.remove()
    }
  }

  override fun onFlutterUiDisplayed() {
    super.onFlutterUiDisplayed()
    val view = brandSplash ?: return
    brandSplash = null
    view.animate()
      .alpha(0f)
      .setDuration(220)
      .withEndAction {
        (view.parent as? ViewGroup)?.removeView(view)
      }
      .start()
  }
}
