allprojects {
    repositories {
        google()
        mavenCentral()
        // On-device OCR engine only (SPEC §3). exclusiveContent: JitPack may serve nothing else. Not declared at all
        // when the engine is built from source (F-Droid).
        if (!providers.gradleProperty("ledgerlockTesseractSrc").isPresent) {
            exclusiveContent {
                forRepository { maven("https://jitpack.io") }
                filter { includeGroup("cz.adaptech.tesseract4android") }
            }
        }
    }
}

// Read by Tesseract4Android's own build.gradle (publishing block) when it is built from source.
extra["tesseract4AndroidVersion"] = "4.9.0"

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// biometric_storage still declares compileSdk 31, but its androidx.biometric dependency needs 33+.
// Raise old plugins' compile SDK (API headers only; no behaviour change). Must run before evaluationDependsOn.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension> {
            finalizeDsl {
                if ((it.compileSdk ?: 0) < 36) it.compileSdk = 36
                // Tesseract4Android from source pins NDK 27.2; build it with the app's NDK so one NDK serves the whole
                // build (no extra SDK download; r28 has 16 KB pages by default).
                if (project.name == "tesseract4android") it.ndkVersion = "28.2.13676358"
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
