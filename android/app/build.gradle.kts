import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (SECURITY A2): the owner's key, read from android/key.properties, which is gitignored and never
// committed. Without that file (contributors, F-Droid, CI) release builds fall back to the debug key; F-Droid
// signs with its own key anyway.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.darkdev.ledgerlock"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.darkdev.ledgerlock"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Tesseract4Android from source has standard/openmp flavours; the JitPack AAR is "standard".
        missingDimensionStrategy("parallelization", "standard")
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Only when the owner has filled in the password: an empty one would fail the build instead of falling back.
        if (!keyProps.getProperty("storeFile").isNullOrBlank() && !keyProps.getProperty("storePassword").isNullOrBlank()) {
            create("release") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword") ?: keyProps.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Tesseract 5 + Leptonica, Apache-2.0, no networking (checked: no curl/socket symbols in the .so files).
    // F-Droid builds it from source (tool/fdroid/fetch_tesseract.sh); otherwise the same tag's JitPack AAR.
    if (rootProject.findProject(":tesseract4android") != null) {
        implementation(project(":tesseract4android"))
    } else {
        implementation("cz.adaptech.tesseract4android:tesseract4android:4.9.0")
    }
}
