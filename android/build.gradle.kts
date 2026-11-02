allprojects {
    repositories {
        google()
        mavenCentral()
        // On-device OCR engine only (SPEC §3). exclusiveContent: JitPack may serve nothing else.
        exclusiveContent {
            forRepository { maven("https://jitpack.io") }
            filter { includeGroup("cz.adaptech.tesseract4android") }
        }
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
// biometric_storage still declares compileSdk 31, but its androidx.biometric dependency needs 33+.
// Raise old plugins' compile SDK (API headers only; no behaviour change). Must run before evaluationDependsOn.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension> {
            finalizeDsl { if ((it.compileSdk ?: 0) < 36) it.compileSdk = 36 }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
