// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/WindowsTab.qml
//
// The Appearance page's Windows tab.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "windows"

    FlyoutHeading { text: "WINDOWS" }

    HyprInt { label: "Gaps between windows"; path: ["general"]; key: "gaps_in"; max: 20 }
    HyprInt { label: "Gaps at screen edges"; path: ["general"]; key: "gaps_out"; max: 40 }
    HyprPercent { label: "Focused opacity"; path: ["decoration"]; key: "active_opacity" }
    HyprPercent { label: "Unfocused opacity"; path: ["decoration"]; key: "inactive_opacity" }
    HyprToggle { label: "Dim unfocused"; path: ["decoration"]; key: "dim_inactive" }
    HyprPercent { label: "Dim strength"; visible: page.hyprField(["decoration"], "dim_inactive").value === true; path: ["decoration"]; key: "dim_strength"; min: 0 }
    HyprToggle { label: "Blur"; note: "Behind translucent windows and layers"; path: ["decoration", "blur"]; key: "enabled" }
    HyprInt { label: "Blur size"; visible: page.blurOn; note: "How far each pass spreads"; path: ["decoration", "blur"]; key: "size"; min: 1; max: 20 }
    HyprInt { label: "Blur passes"; visible: page.blurOn; note: "More is smoother and costs more"; path: ["decoration", "blur"]; key: "passes"; min: 1; max: 4; suffix: "" }

}
