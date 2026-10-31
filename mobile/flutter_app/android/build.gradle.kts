allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val localAppData = System.getenv("LOCALAPPDATA")
val newBuildDir: Directory =
    if (localAppData != null) {
        rootProject.layout.projectDirectory.dir(
            "$localAppData/ResQRoad/${rootProject.name}",
        )
    } else {
        rootProject.layout.buildDirectory.dir("../../build").get()
    }
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
plugins {
  // ...

  // Add the dependency for the Google services Gradle plugin
  id("com.google.gms.google-services") version "4.5.0" apply false

}
