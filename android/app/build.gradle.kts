import java.util.Properties

// Kunci rilis dibaca dari android/key.properties (dibuat oleh workflow dari GitHub Secrets).
// Build RILIS tanpa file itu GAGAL, supaya APK berkunci debug tidak keluar tanpa sengaja.
// Untuk build uji tanpa kunci (fork/PR yang tidak punya secret), nyalakan dengan sengaja:
//   -PallowDebugSigning=true   (atau env ORG_GRADLE_PROJECT_allowDebugSigning=true)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val allowDebugSigning = (findProperty("allowDebugSigning") as String?) == "true"

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.razarsa"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.razarsa"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Tanpa key.properties, hanya sampai di sini kalau build rilis diizinkan memakai kunci debug
            // (lihat pengaman di bawah); tugas lain, mis. build debug, tidak terpengaruh.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Pengaman: build rilis tanpa kunci rilis dan tanpa izin eksplisit dibatalkan dengan pesan yang jelas.
gradle.taskGraph.whenReady {
    val releaseBuild = allTasks.any {
        val n = it.name
        (n.startsWith("assemble") || n.startsWith("bundle") || n.startsWith("package") || n.startsWith("sign")) &&
            n.endsWith("Release")
    }
    if (releaseBuild && !keystorePropertiesFile.exists() && !allowDebugSigning) {
        throw GradleException(
            "Build rilis dibatalkan: android/key.properties tidak ada, jadi APK akan memakai kunci debug. " +
                "Pasang kunci rilis, atau untuk build uji sengaja tambahkan -PallowDebugSigning=true."
        )
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
    // Dibutuhkan flutter_local_notifications (notifikasi terjadwal).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
}
