// Singularity - Quickshell
// ~/.config/quickshell/services/AppStyle.js
//
// qss(): the Qt stylesheet for qt6ct's Fusion (AppearanceSync writes it).
// One flat look whatever the shell's style, like adw-gtk3 and libadwaita
// give GTK apps; only the colours come from the look. Takes t:
//   c          hex colours: the ramp (base … bright), accent, onAccent
//   isLight    the ramp's ground is light

.pragma library

function block(sel, props) {
    var body = ""
    for (var k in props) body += "  " + k + ": " + props[k] + ";\n"
    return sel + " {\n" + body + "}\n"
}

function qss(t) {
    var c = t.c, css = ""
    var line = "1px solid " + c.border

    // spin boxes stay Fusion's: a sheet on them drops their arrows
    css += block("QPushButton, QToolButton[popupMode], QComboBox", {
        "border": line, "background": c.surface, "color": c.text, "border-radius": "6px",
        "min-height": "20px", "padding": "5px 10px" })
    css += block("QPushButton:hover, QToolButton[popupMode]:hover, QComboBox:hover", { "background": c.overlay })
    css += block("QPushButton:pressed, QPushButton:checked, QToolButton:checked", { "background": c.overlay })
    css += block("QPushButton:default", { "background": c.accent, "color": c.onAccent, "border-color": c.accent })
    css += block("QPushButton:disabled, QComboBox:disabled, QLineEdit:disabled", { "color": c.muted })
    css += block("QToolButton", { "border-radius": "6px", "padding": "4px" })
    css += block("QToolButton:hover", { "background": c.overlay })

    css += block("QLineEdit, QComboBox:editable, QPlainTextEdit, QTextEdit", {
        "border": line, "background": c.bar, "color": c.text, "border-radius": "6px",
        "min-height": "26px", "padding": "0 8px",
        "selection-background-color": c.accent, "selection-color": c.onAccent })
    css += block("QPlainTextEdit, QTextEdit", { "border-radius": "8px", "padding": "4px" })
    css += block("QLineEdit:focus, QPlainTextEdit:focus, QTextEdit:focus", { "border": "1px solid " + c.accent })

    css += block("QCheckBox::indicator, QRadioButton::indicator, QAbstractItemView::indicator", {
        "border": line, "width": "14px", "height": "14px", "background": c.bar, "border-radius": "4px" })
    css += block("QRadioButton::indicator", { "border-radius": "8px" })
    css += block("QCheckBox::indicator:checked, QRadioButton::indicator:checked, QAbstractItemView::indicator:checked",
        { "background": c.accent, "border-color": c.accent })

    // panels: group boxes, tab panes, lists, menus, tooltips
    css += block("QGroupBox", { "border": line, "border-radius": "8px", "margin-top": "1.4em", "padding": "8px", "background": c.surface })
    css += block("QGroupBox::title", { "subcontrol-origin": "margin", "left": "10px", "padding": "0 4px", "color": c.bright })
    css += block("QTabWidget::pane", { "border": line, "border-radius": "8px", "top": "-1px", "background": c.surface })
    css += block("QTabBar::tab", {
        "background": "transparent", "color": c.subtext, "padding": "5px 12px",
        "border-radius": "6px", "margin": "2px", "min-height": "14px" })
    css += block("QTabBar::tab:selected", { "background": c.accent, "color": c.onAccent })
    css += block("QTabBar::tab:hover:!selected", { "background": c.overlay, "color": c.text })
    css += block("QListView, QTreeView, QTableView, QListWidget, QTreeWidget", {
        "border": line, "border-radius": "8px", "background": c.bar, "padding": "2px",
        "selection-background-color": c.accent, "selection-color": c.onAccent })
    css += block("QListView::item, QTreeView::item", { "border-radius": "6px", "padding": "4px 6px" })
    css += block("QListView::item:hover, QTreeView::item:hover", { "background": c.overlay })
    css += block("QListView::item:selected, QTreeView::item:selected", { "background": c.accent, "color": c.onAccent })
    css += block("QMenu", { "border": line, "background": t.isLight ? c.panel : c.overlay, "border-radius": "8px", "padding": "4px" })
    css += block("QMenu::item", { "padding": "5px 16px", "border-radius": "6px" })
    css += block("QMenu::item:selected", { "background": c.accent, "color": c.onAccent })
    css += block("QToolTip", { "border": line, "background": c.overlay, "color": c.text, "border-radius": "8px", "padding": "4px" })

    // levels
    css += block("QProgressBar", { "border": "none", "background": c.base, "border-radius": "4px", "max-height": "8px", "text-align": "center", "color": "transparent" })
    css += block("QProgressBar::chunk", { "background": c.accent, "border-radius": "4px" })
    css += block("QSlider::groove:horizontal", { "height": "6px", "background": c.base, "border-radius": "3px" })
    css += block("QSlider::sub-page:horizontal", { "background": c.accent, "border-radius": "3px" })
    css += block("QSlider::handle:horizontal", { "width": "16px", "margin": "-5px 0", "background": c.bright, "border-radius": "8px" })
    css += block("QScrollBar:vertical", { "width": "10px", "background": "transparent" })
    css += block("QScrollBar::handle:vertical", { "background": c.muted, "border-radius": "4px", "min-height": "24px", "margin": "2px" })
    css += block("QScrollBar::add-line, QScrollBar::sub-line, QScrollBar::add-page, QScrollBar::sub-page", { "background": "none", "border": "none", "height": "0px" })
    return css
}
