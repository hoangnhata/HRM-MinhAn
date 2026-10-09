import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Đăng ký trước evaluationDependsOn. file_picker 8.x ghim compileSdk 34,
// trong khi flutter_plugin_android_lifecycle yêu cầu API 36.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByType(BaseExtension::class.java) ?: return@afterEvaluate
        val current = androidExt.compileSdkVersion
            ?.removePrefix("android-")
            ?.toIntOrNull()
            ?: 0
        if (current in 1 until 36) {
            androidExt.compileSdkVersion(36)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
