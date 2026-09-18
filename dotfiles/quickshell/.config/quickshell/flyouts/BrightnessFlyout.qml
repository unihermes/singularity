// Neutrino - Quickshell
// ~/.config/quickshell/flyouts/BrightnessFlyout.qml
//
// Needs bar's brightness readout/setter, and root's Night Light state --
// see the toggle in ControlCentre's Quick Actions for the same fields.

import "../services"
import QtQuick

FlyoutPanel {
    flyout: "brightness"
    menuWidth: 220

    required property var bar
    required property var shellRoot

    FlyoutHeading { text: "BRIGHTNESS  " + bar.brightness + "%" }

    Slider {
        width: parent.width
        value: bar.brightness
        onMoved: v => bar.setBrightness(v)
    }

    FlyoutDivider {}

    FlyoutAction {
        icon: shellRoot.nightLight ? "󰖔" : "󰖙"
        label: "Night Light"
        status: !shellRoot.hasHyprsunset ? "hyprsunset not installed" : ""
        enabled: shellRoot.hasHyprsunset
        checked: shellRoot.nightLight
        onActivated: shellRoot.nightLight = !shellRoot.nightLight
    }

    // Same reasoning as Quick Actions' stepper: only shown while there's an
    // effect to see.
    FlyoutStepper {
        visible: shellRoot.nightLight
        label: "Warmth"
        labelInset: 28
        valueWidth: 44
        suffix: "K"
        value: Settings.nightLightKelvin
        minimum: Settings.limits.nightLightKelvin.min
        maximum: Settings.limits.nightLightKelvin.max
        onStepped: d => Settings.step("nightLightKelvin", d * 250)
    }
}
