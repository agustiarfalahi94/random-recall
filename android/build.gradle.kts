buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.1")
    }
}

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
subprojects {
    project.evaluationDependsOn(":app")
}

// Force all plugin subprojects to compile with a Kotlin language version
// that is supported by the Kotlin 2.x compiler (1.6 was dropped in 2.x),
// and match each module's own Java source/target compatibility so AGP's
// Java-vs-Kotlin JVM-target consistency check passes for both old plugins
// (Java 1.8: app_settings, workmanager, flutter_jailbreak_detection) and
// modern ones (Java 17: Firebase, sqflite, ...).
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            languageVersion.set(
                org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9
            )
            apiVersion.set(
                org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9
            )
        }
        val androidExt =
            project.extensions.findByType<com.android.build.gradle.LibraryExtension>()
        if (androidExt != null) {
            val javaVersion = androidExt.compileOptions.sourceCompatibility
            val jvmTarget = when (javaVersion?.toString()) {
                "17" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                "11" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
            }
            compilerOptions.jvmTarget.set(jvmTarget)
        }
    }
}

// flutter_jailbreak_detection (unmaintained) predates AGP 8 namespaces and
// never declares one, which fails configuration. Set it from the plugin's
// manifest package before AGP builds its variants.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            if (namespace.isNullOrEmpty()) {
                namespace = "appmire.be.flutterjailbreakdetection"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
