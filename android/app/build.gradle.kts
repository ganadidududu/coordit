import java.util.Properties
import java.net.URI

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}
fun quoted(value: String) = "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
val debugApi = providers.gradleProperty("COORDIT_API_BASE_URL").orElse("http://10.0.2.2:4000/")
val releaseApi = providers.gradleProperty("COORDIT_RELEASE_API_BASE_URL").orElse("https://unconfigured.invalid/")
val debugAdMobAppId = "ca-app-pub-3940256099942544~3347511713"
val debugRewardedAdUnitId = "ca-app-pub-3940256099942544/5224354917"
val releaseAdMobAppId = providers.gradleProperty("ADMOB_APP_ID").orElse("")
val releaseRewardedAdUnitId = providers.gradleProperty("ADMOB_REWARDED_AD_UNIT_ID").orElse("")
val signingPropertiesFile = rootProject.file(providers.environmentVariable("COORDIT_SIGNING_PROPERTIES").orElse("signing/release.properties").get())
val uploadSigning = Properties().apply { if (signingPropertiesFile.isFile) signingPropertiesFile.inputStream().use(::load) }
require(releaseApi.get().startsWith("https://")) { "Release API URL must use HTTPS" }
android {
    namespace = "com.inseong.coordit"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.coordit.app"
        minSdk = 26
        targetSdk = 36
        versionCode = providers.gradleProperty("COORDIT_VERSION_CODE").orElse("12").get().toInt()
        versionName = providers.gradleProperty("COORDIT_VERSION_NAME").orElse("1.0.3").get()
        buildConfigField("boolean", "CARDLESS_AR_ENABLED", "false")
        buildConfigField("boolean", "AI_LANDMARKS_ENABLED", "false")
        buildConfigField("boolean", "AI_LANDMARKS_DEVELOPMENT_ENABLED", "false")
        buildConfigField("boolean", "RGB_ESTIMATE_ENABLED", "false")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", quoted(providers.gradleProperty("GOOGLE_WEB_CLIENT_ID").orElse("").get()))
    }
    signingConfigs {
        if (signingPropertiesFile.isFile) create("upload") {
            storeFile = rootProject.file(uploadSigning.getProperty("storeFile"))
            storePassword = uploadSigning.getProperty("storePassword")
            keyAlias = uploadSigning.getProperty("keyAlias")
            keyPassword = uploadSigning.getProperty("keyPassword")
        }
    }
    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            buildConfigField("String", "API_BASE_URL", quoted(debugApi.get()))
            buildConfigField("String", "ADMOB_REWARDED_AD_UNIT_ID", quoted(debugRewardedAdUnitId))
            buildConfigField("boolean", "ADMOB_REWARDED_ENABLED", "true")
            manifestPlaceholders["cleartextAllowed"] = "true"
            manifestPlaceholders["adMobApplicationId"] = debugAdMobAppId
        }
        release {
            signingConfig = signingConfigs.findByName("upload")
            isMinifyEnabled = false
            buildConfigField("String", "API_BASE_URL", quoted(releaseApi.get()))
            buildConfigField("String", "ADMOB_REWARDED_AD_UNIT_ID", quoted(releaseRewardedAdUnitId.get()))
            buildConfigField("boolean", "ADMOB_REWARDED_ENABLED", (releaseAdMobAppId.get().isNotBlank() && releaseRewardedAdUnitId.get().isNotBlank()).toString())
            manifestPlaceholders["cleartextAllowed"] = "false"
            // The SDK is never initialized in this variant until both production values above are supplied.
            manifestPlaceholders["adMobApplicationId"] = releaseAdMobAppId.get().ifBlank { debugAdMobAppId }
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    buildFeatures { compose = true; buildConfig = true }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}
tasks.matching { it.name == "bundleRelease" }.configureEach {
    doFirst {
        require(signingPropertiesFile.isFile) { "Create an upload key with scripts/create-upload-key.sh or set COORDIT_SIGNING_PROPERTIES." }
        require(URI(releaseApi.get()).host?.endsWith(".invalid") == false) { "Configure COORDIT_RELEASE_API_BASE_URL before building a release bundle." }
    }
}
dependencies {
    implementation("com.google.ar:core:1.57.0")
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    androidTestImplementation(composeBom)
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
    implementation("androidx.exifinterface:exifinterface:1.3.7")
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
    // 24.x is compiled with newer Kotlin metadata; 23.6.0 remains compatible with Kotlin 2.0.21.
    implementation("com.google.android.gms:play-services-ads:23.6.0")
    implementation("com.google.android.ump:user-messaging-platform:4.0.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.navigation:navigation-compose:2.8.5")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-gson:2.11.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}

androidComponents {
    onVariants(selector().withBuildType("debug")) { variant ->
        variant.applicationId.set("com.inseong.coordit.debug")
    }
}
