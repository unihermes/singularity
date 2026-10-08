# LibreOffice set up to feel like Word: the ribbon (Tabbed) in every app,
# .docx/.xlsx/.pptx as the save formats, a Normal.ott default template with
# Word's styles in Carlito (Calibri's metric twin), and Zotero's add-in.
# Everything lands in the user profile, so any of it can be changed back in
# LibreOffice afterwards and nothing here runs again.
command -v soffice &>/dev/null || exit 0

if pgrep -x soffice.bin &>/dev/null; then
  die "LibreOffice is open. Close it, then rerun ./link.sh"
fi

user="$HOME/.config/libreoffice/4/user"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

# The template, written flat and converted. Word's Normal: 11 pt, 1.08 line
# spacing, 8 pt after; headings in its blue, each followed by Normal; Letter
# with 1 in margins and tab stops every half inch.
cat > "$work/Normal.fodt" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<office:document xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
 xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
 xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
 xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
 xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"
 office:version="1.3" office:mimetype="application/vnd.oasis.opendocument.text">
 <office:font-face-decls>
  <style:font-face style:name="Carlito" svg:font-family="Carlito" style:font-family-generic="swiss" style:font-pitch="variable"/>
 </office:font-face-decls>
 <office:styles>
  <style:default-style style:family="paragraph">
   <style:paragraph-properties style:tab-stop-distance="0.5in" fo:hyphenation-ladder-count="no-limit" style:writing-mode="page"/>
   <style:text-properties style:font-name="Carlito" fo:font-size="11pt" fo:language="en" fo:country="US" fo:hyphenate="false"
    style:font-name-asian="Carlito" style:font-size-asian="11pt" style:font-name-complex="Carlito" style:font-size-complex="11pt"/>
  </style:default-style>
  <style:style style:name="Standard" style:family="paragraph" style:class="text">
   <style:paragraph-properties fo:margin-top="0pt" fo:margin-bottom="8pt" fo:line-height="108%" fo:orphans="2" fo:widows="2"/>
  </style:style>
  <style:style style:name="Text_20_body" style:display-name="Text Body" style:family="paragraph" style:parent-style-name="Standard" style:class="text"/>
  <style:style style:name="Heading" style:family="paragraph" style:parent-style-name="Standard" style:next-style-name="Standard" style:class="text">
   <style:paragraph-properties fo:margin-bottom="0pt" fo:keep-with-next="always"/>
   <style:text-properties fo:color="#2f5496" style:font-name="Carlito" style:font-name-asian="Carlito" style:font-name-complex="Carlito"/>
  </style:style>
  <style:style style:name="Heading_20_1" style:display-name="Heading 1" style:family="paragraph" style:parent-style-name="Heading" style:next-style-name="Standard" style:default-outline-level="1" style:class="text">
   <style:paragraph-properties fo:margin-top="12pt"/>
   <style:text-properties fo:font-size="16pt" fo:font-weight="normal" style:font-size-asian="16pt" style:font-weight-asian="normal" style:font-size-complex="16pt" style:font-weight-complex="normal"/>
  </style:style>
  <style:style style:name="Heading_20_2" style:display-name="Heading 2" style:family="paragraph" style:parent-style-name="Heading" style:next-style-name="Standard" style:default-outline-level="2" style:class="text">
   <style:paragraph-properties fo:margin-top="2pt"/>
   <style:text-properties fo:font-size="13pt" fo:font-weight="normal" style:font-size-asian="13pt" style:font-weight-asian="normal" style:font-size-complex="13pt" style:font-weight-complex="normal"/>
  </style:style>
  <style:style style:name="Heading_20_3" style:display-name="Heading 3" style:family="paragraph" style:parent-style-name="Heading" style:next-style-name="Standard" style:default-outline-level="3" style:class="text">
   <style:paragraph-properties fo:margin-top="2pt"/>
   <style:text-properties fo:color="#1f3763" fo:font-size="12pt" fo:font-weight="normal" style:font-size-asian="12pt" style:font-weight-asian="normal" style:font-size-complex="12pt" style:font-weight-complex="normal"/>
  </style:style>
  <style:style style:name="Title" style:family="paragraph" style:parent-style-name="Standard" style:next-style-name="Standard" style:class="chapter">
   <style:paragraph-properties fo:margin-bottom="0pt" fo:line-height="100%" fo:text-align="start"/>
   <style:text-properties fo:font-size="28pt" fo:letter-spacing="-0.5pt" style:font-size-asian="28pt" style:font-size-complex="28pt"/>
  </style:style>
  <style:style style:name="Subtitle" style:family="paragraph" style:parent-style-name="Standard" style:next-style-name="Standard" style:class="chapter">
   <style:paragraph-properties fo:margin-top="0pt" fo:text-align="start"/>
   <style:text-properties fo:color="#595959" fo:letter-spacing="0.75pt" style:font-size-asian="11pt" style:font-size-complex="11pt"/>
  </style:style>
 </office:styles>
 <office:automatic-styles>
  <style:page-layout style:name="pm1">
   <style:page-layout-properties fo:page-width="8.5in" fo:page-height="11in" style:print-orientation="portrait"
    fo:margin-top="1in" fo:margin-bottom="1in" fo:margin-left="1in" fo:margin-right="1in"/>
  </style:page-layout>
 </office:automatic-styles>
 <office:master-styles>
  <style:master-page style:name="Standard" style:page-layout-name="pm1"/>
 </office:master-styles>
 <office:body>
  <office:text>
   <text:p text:style-name="Standard"/>
  </office:text>
 </office:body>
</office:document>
EOF

# A headless run also creates the profile on a machine where LibreOffice has
# never opened, so the registry below has a file to go into.
mkdir -p "$user/template"
soffice --headless --infilter="OpenDocument Text Flat XML" --convert-to ott:writer8_template --outdir "$user/template" "$work/Normal.fodt" >/dev/null 2>&1 \
  || die "LibreOffice could not write the Normal template"

python3 -I - "$user/registrymodifications.xcu" <<'EOF'
import sys

TABBED = "notebookbar.ui"
MODES = "/org.openoffice.Office.UI.ToolbarMode"
FACTORY = "/org.openoffice.Setup/Office/Factories/org.openoffice.Setup:Factory['{}']"

settings = [
    (MODES, f"Active{app}", TABBED) for app in ("Writer", "Calc", "Impress", "Draw")
] + [
    (f"{MODES}/Applications/org.openoffice.Office.UI.ToolbarMode:Application['{app}']", "Active", TABBED)
    for app in ("Writer", "Calc", "Impress", "Draw")
] + [
    (f"{MODES}/Applications/org.openoffice.Office.UI.ToolbarMode:Application['{app}']"
     "/Modes/org.openoffice.Office.UI.ToolbarMode:ModeEntry['Tabbed']", "HasMenubar", "false")
    for app in ("Writer", "Calc", "Impress", "Draw")
] + [
    (FACTORY.format("com.sun.star.text.TextDocument"), "ooSetupFactoryDefaultFilter", "MS Word 2007 XML"),
    (FACTORY.format("com.sun.star.sheet.SpreadsheetDocument"), "ooSetupFactoryDefaultFilter", "Calc MS Excel 2007 XML"),
    (FACTORY.format("com.sun.star.presentation.PresentationDocument"), "ooSetupFactoryDefaultFilter", "Impress MS PowerPoint 2007 XML"),
    (FACTORY.format("com.sun.star.text.TextDocument"), "ooSetupFactoryTemplateFile", "$(user)/template/Normal.ott"),
    ("/org.openoffice.Office.Common/Save/Document", "WarnAlienFormat", "false"),
    # Fonts for documents that don't come from the template (HTML, plain text).
    *[("/org.openoffice.Office.Writer/DefaultFont", f, "Carlito")
      for f in ("Standard", "Heading", "List", "Caption", "Index")],
]

path = sys.argv[1]
try:
    lines = open(path, encoding="utf-8").read().splitlines()
except FileNotFoundError:
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<oor:items xmlns:oor="http://openoffice.org/2001/registry" '
             'xmlns:xs="http://www.w3.org/2001/XMLSchema" '
             'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">',
             '</oor:items>']

keys = {f'<item oor:path="{p}"><prop oor:name="{n}"' for p, n, _ in settings}
lines = [l for l in lines if not any(l.startswith(k) for k in keys)]
end = lines.index("</oor:items>")
lines[end:end] = [
    f'<item oor:path="{p}"><prop oor:name="{n}" oor:op="fuse"><value>{v}</value></prop></item>'
    for p, n, v in settings
]
open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
EOF
log "LibreOffice: ribbon, Office formats and a Word-like Normal template"

# Zotero's add-in ships inside Zotero. Without Zotero now, install it later
# from Zotero's Settings › Cite › Word Processors.
oxt=$(compgen -G "/usr/lib/zotero*/integration/libreoffice/Zotero_LibreOffice_Integration.oxt" | head -n1 || true)
if [[ -n $oxt ]]; then
  unopkg add --force --suppress-license "$oxt" >/dev/null || die "could not add Zotero's LibreOffice add-in"
  log "LibreOffice: added the Zotero add-in"
fi
