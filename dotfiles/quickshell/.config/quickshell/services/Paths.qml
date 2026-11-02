// Shared writable locations; state-paths.py maintains legacy compatibility links.
pragma Singleton
import Quickshell

Singleton {
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/singularity"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/singularity"
    // Provider histories are indexed by cwd. Keep its spelling stable across XDG changes.
    readonly property string chatDir: home + "/.cache/singularity/ai/chat"
}
