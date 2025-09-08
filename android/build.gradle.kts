buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.9.1") // Android Gradle Plugin version
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0") // Kotlin version
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

