pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    // Lets Gradle fetch the JDK 17 that biometric_storage requires (build-time only).
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

include(":app")

// F-Droid / from-source builds: compile the OCR engine from a Tesseract4Android checkout instead of downloading the
// JitPack AAR. Set with -PledgerlockTesseractSrc=<dir> or ORG_GRADLE_PROJECT_ledgerlockTesseractSrc (see
// tool/fdroid/fetch_tesseract.sh).
providers.gradleProperty("ledgerlockTesseractSrc").orNull?.let { src ->
    include(":tesseract4android")
    project(":tesseract4android").projectDir = file(src).resolve("tesseract4android")
}
