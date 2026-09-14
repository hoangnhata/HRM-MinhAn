package com.minhan.hrm.hrm_mobile

import android.animation.Animator
import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hiện brand splash (logo + chữ + load) ngay khi Activity mở,
 * đè lên khoảng chờ Flutter engine — tránh màn teal trống.
 */
class MainActivity : FlutterActivity() {
  private var brandSplash: View? = null
  private val splashAnimators = mutableListOf<Animator>()

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "com.minhan.hrm/app_badge",
    ).setMethodCallHandler { call, result ->
      if (call.method == "setBadge") {
        // Số trên icon Android phụ thuộc launcher; FCM notificationCount là nguồn chính.
        // Channel tồn tại để Flutter không lỗi khi sync giống iOS.
        result.success(null)
      } else {
        result.notImplemented()
      }
    }
  }

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
    startBrandSplashAnimations(overlay)

    // Chuyển mềm từ splash hệ thống sang lớp brand đầy đủ.
    splashScreen.setOnExitAnimationListener { provider ->
      provider.view.animate()
        .alpha(0f)
        .setDuration(180)
        .setInterpolator(DecelerateInterpolator())
        .withEndAction { provider.remove() }
        .start()
    }
  }

  private fun startBrandSplashAnimations(root: View) {
    val logo = root.findViewById<View>(R.id.splashLogoStage)
    val copy = root.findViewById<View>(R.id.splashCopy)
    val footer = root.findViewById<View>(R.id.splashFooter)
    val halo = root.findViewById<View>(R.id.splashHaloPulse)

    logo.alpha = 0f
    logo.scaleX = 0.84f
    logo.scaleY = 0.84f
    logo.translationY = 18f
    logo.animate()
      .alpha(1f)
      .scaleX(1f)
      .scaleY(1f)
      .translationY(0f)
      .setStartDelay(70)
      .setDuration(620)
      .setInterpolator(OvershootInterpolator(0.72f))
      .start()

    copy.alpha = 0f
    copy.translationY = 16f
    copy.animate()
      .alpha(1f)
      .translationY(0f)
      .setStartDelay(220)
      .setDuration(480)
      .setInterpolator(DecelerateInterpolator())
      .start()

    footer.alpha = 0f
    footer.animate()
      .alpha(1f)
      .setStartDelay(420)
      .setDuration(420)
      .start()

    val haloPulse = ObjectAnimator.ofPropertyValuesHolder(
      halo,
      PropertyValuesHolder.ofFloat(View.SCALE_X, 0.92f, 1.07f),
      PropertyValuesHolder.ofFloat(View.SCALE_Y, 0.92f, 1.07f),
      PropertyValuesHolder.ofFloat(View.ALPHA, 0.42f, 0.88f),
    ).apply {
      startDelay = 520
      duration = 1750
      repeatCount = ObjectAnimator.INFINITE
      repeatMode = ObjectAnimator.REVERSE
      interpolator = AccelerateDecelerateInterpolator()
    }

    val logoBreath = ObjectAnimator.ofPropertyValuesHolder(
      logo,
      PropertyValuesHolder.ofFloat(View.SCALE_X, 1f, 1.018f),
      PropertyValuesHolder.ofFloat(View.SCALE_Y, 1f, 1.018f),
    ).apply {
      startDelay = 900
      duration = 2100
      repeatCount = ObjectAnimator.INFINITE
      repeatMode = ObjectAnimator.REVERSE
      interpolator = AccelerateDecelerateInterpolator()
    }

    splashAnimators += haloPulse
    splashAnimators += logoBreath
    haloPulse.start()
    logoBreath.start()
  }

  override fun onFlutterUiDisplayed() {
    super.onFlutterUiDisplayed()
    val view = brandSplash ?: return
    brandSplash = null
    splashAnimators.forEach(Animator::cancel)
    splashAnimators.clear()
    view.findViewById<View>(R.id.splashLogoStage)?.animate()
      ?.scaleX(1.035f)
      ?.scaleY(1.035f)
      ?.setDuration(280)
      ?.start()
    view.animate()
      .alpha(0f)
      .setDuration(320)
      .setInterpolator(AccelerateDecelerateInterpolator())
      .withEndAction {
        (view.parent as? ViewGroup)?.removeView(view)
      }
      .start()
  }
}
