// Source-tree access for tests that lint `src/main` itself.

package com.siansiansu.taigikeyboard

import org.junit.Assert.fail
import java.io.File

/**
 * Locate `src/main/java` from either the repo root or the `android/` /
 * `android/app` subdirectory — tests launched by Gradle typically set
 * `user.dir` to the project module, while tests launched from IDE run-configs
 * sometimes start at the repo root.
 */
internal fun locateMainSourceRoot(): File {
    val candidates =
        listOf(
            "src/main/java",
            "app/src/main/java",
            "android/app/src/main/java",
        )
    for (rel in candidates) {
        val f = File(rel)
        if (f.isDirectory) return f.absoluteFile
    }
    fail("Could not locate `src/main/java` from working dir ${File(".").absolutePath}")
    error("unreachable")
}

/** Every Kotlin source file under [root]. */
internal fun mainKotlinSources(root: File): Sequence<File> = root.walkTopDown().filter { it.isFile && it.extension == "kt" }
