// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageConfig.qml
//
// Every file this desktop is actually configured by, in one list, each one
// a click away from an editor. The old window had two of these links; the
// point of the page is that "where do I change that" is the question every
// other page ends on, and the answer should not be a filesystem hunt.
//
// Paths are checked once when the page opens, in a single process, and a
// file that isn't there is greyed rather than hidden -- seeing that a file
// you expected is missing is half of what this page is for.
//
// The repository root is resolved rather than assumed: ~/.config/quickshell
// is a symlink into the dotfiles repo (see install.sh), so following it and
// walking up gives the checkout wherever it was cloned.

import Quickshell
import Quickshell.Io
import QtQuick
import "../../services"
import "../../flyouts"
// the page's own building blocks next door; QML needs the directory named
import "../system"

SystemPage {
    id: page

    title: "Config"
    subtitle: "Click to open in the editor; the folder button on the right reveals it. "
        + "Files under /etc open read-only unless the editor is given a way to elevate."

    readonly property string home: Quickshell.env("HOME")
    // filled in by rootProc; empty until then, which simply leaves the
    // repository group's rows greyed for the frame before it lands
    property string repo: ""
    // path -> bool, from existsProc
    property var present: ({})

    function has(p) { return present[p] === true }

    readonly property var groups: [
        {
            heading: "THE SHELL",
            items: [
                { label: "shell.qml", path: home + "/.config/quickshell/shell.qml",
                  note: "Entry point: the bar, the flyouts and the windows" },
                { label: "Settings.qml", path: home + "/.config/quickshell/services/Settings.qml",
                  note: "Every setting's default and where it is persisted" },
                { label: "Theme.qml", path: home + "/.config/quickshell/services/Theme.qml",
                  note: "Colours, type scale, spacing, radii — the design tokens" },
                { label: "looks.json", path: home + "/.config/quickshell/services/looks.json",
                  note: "The palettes and frame styles the Appearance page offers" },
                { label: "BarModules.qml", path: home + "/.config/quickshell/bar/BarModules.qml",
                  note: "What each bar module is and what clicking it does" },
                { label: "ControlCentre.qml", path: home + "/.config/quickshell/flyouts/ControlCentre.qml",
                  note: "The flyout this window opens from" },
                { label: "appearance.json", path: Settings.stateDir + "/appearance.json",
                  note: "Saved appearance state — written by the shell, not by hand" },
            ],
        },
        {
            heading: "HYPRLAND",
            items: [
                { label: "hyprland.lua", path: home + "/.config/hypr/hyprland.lua",
                  note: "Keybinds, window rules, input, the default monitor rule" },
                { label: "monitors.lua", path: Settings.stateDir + "/monitors.lua",
                  note: "This machine's display rules — written by the Display page" },
                { label: "hypridle.conf", path: home + "/.config/hypr/hypridle.conf",
                  note: "When the screen dims, locks and suspends" },
                { label: "hyprlock.conf", path: home + "/.config/hypr/hyprlock.conf",
                  note: "The lock screen" },
                { label: "window-rules.json", path: home + "/.config/singularity/window-rules.json",
                  note: "Per-application rules the Settings window edits" },
            ],
        },
        {
            heading: "HYPRLAND SCRIPTS",
            items: [
                { label: "lid.sh", path: home + "/.config/hypr/lid.sh", note: "Lid open and close" },
                { label: "screenshot.sh", path: home + "/.config/hypr/screenshot.sh", note: "Region, window and full captures" },
                { label: "wallpaper.sh", path: home + "/.config/hypr/wallpaper.sh", note: "Setting and cycling the wallpaper" },
                { label: "alttab-ipc.sh", path: home + "/.config/hypr/alttab-ipc.sh", note: "The window switcher's driver" },
                { label: "colour-pick.sh", path: home + "/.config/hypr/colour-pick.sh", note: "Screen colour picker" },
            ],
        },
        {
            heading: "TERMINAL AND PROMPT",
            items: [
                { label: "alacritty.toml", path: home + "/.config/alacritty/alacritty.toml", note: "Font, padding, colours" },
                { label: "starship.toml", path: home + "/.config/starship.toml", note: "The prompt" },
                { label: ".bashrc", path: home + "/.bashrc", note: "Aliases, exports, shell options" },
                { label: "fastfetch config.jsonc", path: home + "/.config/fastfetch/config.jsonc", note: "The login banner" },
            ],
        },
        {
            heading: "APPLICATIONS",
            items: [
                { label: "nvim init.lua", path: home + "/.config/nvim/init.lua", note: "Editor entry point" },
                { label: "zathurarc", path: home + "/.config/zathura/zathurarc", note: "PDF viewer" },
            ],
        },
        {
            heading: "DESKTOP INTEGRATION",
            items: [
                { label: "mimeapps.list", path: home + "/.config/mimeapps.list",
                  note: "Which application opens which file type — the Settings window writes this" },
                { label: "GTK 3 settings.ini", path: home + "/.config/gtk-3.0/settings.ini", note: "Theme, icons, fonts for GTK 3 apps" },
                { label: "GTK 4 settings.ini", path: home + "/.config/gtk-4.0/settings.ini", note: "The same, for GTK 4" },
                { label: "fonts.conf", path: home + "/.config/fontconfig/fonts.conf", note: "Font substitution and rendering" },
                { label: "user-dirs.dirs", path: home + "/.config/user-dirs.dirs", note: "Where Downloads, Documents and the rest point" },
            ],
        },
        {
            heading: "SYSTEM",
            items: [
                { label: "pacman.conf", path: "/etc/pacman.conf", note: "Repositories and package manager options" },
                { label: "fstab", path: "/etc/fstab", note: "What gets mounted at boot" },
                { label: "mkinitcpio.conf", path: "/etc/mkinitcpio.conf", note: "Initramfs modules and hooks" },
                { label: "logind.conf", path: "/etc/systemd/logind.conf", note: "Lid, power button and idle handling" },
                { label: "environment", path: "/etc/environment", note: "System-wide environment variables" },
                { label: "hosts", path: "/etc/hosts", note: "Local name overrides" },
            ],
        },
    ]

    // The repository the dotfiles are stowed from, and the folders worth
    // opening whole rather than as one file.
    readonly property var folders: [
        { label: "Dotfiles repository", path: repo, note: "The checkout everything here is stowed from" },
        { label: "install.sh", path: repo === "" ? "" : repo + "/install.sh", note: "What a fresh machine runs" },
        { label: "packages/pacman.txt", path: repo === "" ? "" : repo + "/packages/pacman.txt", note: "The package list install.sh installs" },
        { label: "~/.config", path: home + "/.config", note: "Everything else" },
        { label: "User systemd units", path: home + "/.config/systemd/user", note: "Timers and services that run as you" },
    ]

    readonly property var allPaths: {
        var out = []
        for (var i = 0; i < groups.length; i++)
            for (var j = 0; j < groups[i].items.length; j++) out.push(groups[i].items[j].path)
        for (var k = 0; k < folders.length; k++) if (folders[k].path !== "") out.push(folders[k].path)
        return out
    }

    Component.onCompleted: rootProc.running = true

    // ~/.config/quickshell is a symlink into dotfiles/quickshell/.config/
    // quickshell inside the repo, so four levels up from the resolved path
    // is the checkout's root.
    Process {
        id: rootProc
        command: ["sh", "-c", "readlink -f \"$HOME/.config/quickshell\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim()
                if (p !== "") {
                    var up = p.split("/")
                    if (up.length > 4) page.repo = up.slice(0, up.length - 4).join("/")
                }
                page.checkPaths()
            }
        }
    }

    function checkPaths() {
        if (existsProc.running) return
        // the paths go in argv rather than through a shell string: a path
        // with a space in it would otherwise split into two tests
        existsProc.command = ["sh", "-c",
            "for p in \"$@\"; do if [ -e \"$p\" ]; then echo 1; else echo 0; fi; done",
            "sh"].concat(allPaths)
        existsProc.running = true
    }

    Process {
        id: existsProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var flags = text.trim().split("\n")
                var map = {}
                for (var i = 0; i < page.allPaths.length; i++)
                    map[page.allPaths[i]] = flags[i] === "1"
                page.present = map
            }
        }
    }

    // --- the lists ----------------------------------------------------------

    Repeater {
        model: page.groups

        Column {
            required property var modelData
            width: parent.width
            spacing: Theme.spaceXs
            bottomPadding: Theme.spaceL

            FlyoutHeading { text: modelData.heading }

            Repeater {
                model: modelData.items

                LinkRow {
                    required property var modelData
                    label: modelData.label
                    path: modelData.path
                    note: modelData.note
                    exists: page.has(modelData.path)
                }
            }
        }
    }

    FlyoutHeading { text: "FOLDERS" }

    Repeater {
        model: page.folders

        LinkRow {
            required property var modelData
            visible: modelData.path !== ""
            label: modelData.label
            path: modelData.path
            note: modelData.note
            exists: page.has(modelData.path)
        }
    }

    // --- logs ----------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "LOGS" }

    Flow {
        width: parent.width
        spacing: Theme.spaceM

        FlyoutChip {
            text: "Shell log"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "journalctl --user -t quickshell -b -e --no-pager || journalctl --user -b -e"])
        }
        FlyoutChip {
            text: "Hyprland log"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "tail -n 200 -f /tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log"])
        }
        FlyoutChip {
            text: "Pacman log"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "tail -n 400 /var/log/pacman.log | less +G"])
        }
        FlyoutChip {
            text: "Boot errors"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "journalctl -b -p err -e"])
        }
    }

    // --- git ------------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "REPOSITORY" }

    InfoRow {
        label: "Checkout"
        value: page.repo !== "" ? page.repo : "not found"
        valueColor: page.repo === "" ? Theme.alert : undefined
    }
    InfoRow { label: "Last upgrade"; value: SystemSpecs.lastUpgrade || "--" }

    Flow {
        width: parent.width
        spacing: Theme.spaceM

        FlyoutChip {
            text: "git status"
            enabled: page.repo !== ""
            onClicked: Quickshell.execDetached(["alacritty", "--working-directory", page.repo,
                "-e", "sh", "-c", "git status; git -P log --oneline -10; read -r _"])
        }
        FlyoutChip {
            text: "Shell in repo"
            enabled: page.repo !== ""
            onClicked: Quickshell.execDetached(["alacritty", "--working-directory", page.repo])
        }
        FlyoutChip {
            text: "Editor in repo"
            enabled: page.repo !== ""
            onClicked: Quickshell.execDetached(["alacritty", "--working-directory", page.repo,
                "-e", "nvim", "."])
        }
    }
}
