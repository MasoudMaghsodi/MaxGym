plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") version "2.1.0" 
    id("com.google.gms.google-services") version "4.4.2" apply true 
    id("com.google.firebase.crashlytics") version "3.0.2" apply true 
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.max_gym"
    compileSdk = 35 
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true 
    }

    kotlin {
        jvmToolchain {
            languageVersion.set(JavaLanguageVersion.of(17)) 
            vendor.set(JvmVendorSpec.ADOPTIUM)
            implementation.set(JvmImplementation.VENDOR_SPECIFIC)
        }
    }

    defaultConfig {
        applicationId = "com.example.max_gym"
        minSdk = 21 
        targetSdk = 35 
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true 
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") 
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") 
    implementation(platform("com.google.firebase:firebase-bom:33.1.2")) 
    implementation("com.google.firebase:firebase-crashlytics")
    implementation("com.google.firebase:firebase-analytics")
    implementation("androidx.multidex:multidex:2.0.1") 
}