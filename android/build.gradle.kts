import org.gradle.api.tasks.Copy
import org.gradle.api.tasks.Delete
import org.gradle.api.JavaVersion

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {

    afterEvaluate {

        println(">>> Configuring subproject: ${project.name}")

        // ✅ Fix namespace if missing
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            try {
                val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(androidExt)

                if (currentNamespace == null) {
                    val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(
                        androidExt,
                        "com.hostel.placeholder." + project.name.replace("-", "_")
                    )
                    println(">>> Namespace set for ${project.name}")
                }
            } catch (_: Exception) {}

            // ✅ Set Java 17
            try {
                val compileOptions = androidExt.javaClass
                    .getMethod("getCompileOptions")
                    .invoke(androidExt)

                val jv17 = JavaVersion.VERSION_17

                compileOptions?.javaClass
                    ?.getMethod("setSourceCompatibility", JavaVersion::class.java)
                    ?.invoke(compileOptions, jv17)

                compileOptions?.javaClass
                    ?.getMethod("setTargetCompatibility", JavaVersion::class.java)
                    ?.invoke(compileOptions, jv17)

                println(">>> Java 17 set for ${project.name}")
            } catch (_: Exception) {}
        }

        // ✅ Set Kotlin JVM target safely
        project.tasks.configureEach {
            if (this.name.contains("Kotlin", ignoreCase = true)) {
                try {
                    val kotlinOptions = this.javaClass
                        .getMethod("getKotlinOptions")
                        .invoke(this)

                    kotlinOptions?.javaClass
                        ?.getMethod("setJvmTarget", String::class.java)
                        ?.invoke(kotlinOptions, "17")

                } catch (_: Exception) {}
            }
        }
    }
}

//////////////////////////////////////////////////////////////
// ✅ COPY APK TASK (FIXED PROPERLY)
//////////////////////////////////////////////////////////////
val copyDebugApkForFlutter = tasks.register<Copy>("copyDebugApkForFlutter") {
    from("$rootDir/app/build/outputs/apk/debug/app-debug.apk")
    into("$rootDir/../build/app/outputs/flutter-apk") // ✅ FIXED
}

afterEvaluate {
    val appProject = project.findProject(":app")

    if (appProject != null) {
        appProject.tasks.matching { it.name == "assembleDebug" }
            .configureEach {
                finalizedBy(copyDebugApkForFlutter)
                println(">>> Hooked copyDebugApkForFlutter to assembleDebug")
            }
    } else {
        println(">>> :app module not found")
    }
}

//////////////////////////////////////////////////////////////
// ✅ CLEAN TASK
//////////////////////////////////////////////////////////////

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}