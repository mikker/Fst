#!/usr/bin/env python3
"""Generate the feed and cask from the exact signed release archive and the CHANGELOG.md section."""
import datetime
import email.utils
import hashlib
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

version = sys.argv[1]
if not re.fullmatch(r"\d+\.\d+(\.\d+)?", version):
    raise SystemExit("Expected version X.Y")
archive = Path("dist/Fst.app.zip")
info = plistlib.loads(Path("build/export/Fst.app/Contents/Info.plist").read_bytes())
assert info["CFBundleShortVersionString"] == version
signature = Path("dist/signature.txt").read_text().strip()
assert re.fullmatch(r"[A-Za-z0-9+/]{86}==", signature), "Invalid Ed25519 signature"
url = f"https://github.com/mikker/Fst/releases/download/v{version}/Fst.app.zip"

# Sparkle shows this in its update window: the system font, the system's light or dark look, and a way to the rest.
# A releaseNotesLink to the GitHub release page would render the whole site, navigation and all.
NOTES_PAGE = """<!doctype html>
<meta charset="utf-8">
<style>
  :root { color-scheme: light dark; }
  body { font: 13px/1.45 -apple-system, sans-serif; margin: 10px 14px; }
  h3 { font-size: 13px; margin: 14px 0 4px; }
  h3:first-child, p:first-child { margin-top: 0; }
  ul { margin: 4px 0; padding-left: 18px; }
  li { margin: 3px 0; }
  code { font: 12px ui-monospace, monospace; }
  footer { margin-top: 14px; opacity: 0.6; }
</style>
{notes}
<footer>Every release: <a href="https://github.com/mikker/Fst/releases">github.com/mikker/Fst/releases</a></footer>
"""


def release_notes(version):
    """The version's section of CHANGELOG.md as a page for Sparkle, rendered by GitHub."""
    lines = Path("CHANGELOG.md").read_text().splitlines()
    heading = f"## {version}"
    if heading not in lines:
        raise SystemExit(f"CHANGELOG.md has no {heading} section")
    body = []
    for line in lines[lines.index(heading) + 1:]:
        if line.startswith("## "):
            break
        body.append(line)
    text = "\n".join(body).strip()
    if not text:
        raise SystemExit(f"The {heading} section of CHANGELOG.md is empty")
    html = subprocess.run(["gh", "api", "markdown", "-f", "mode=gfm", "-f", "context=mikker/Fst", "-f", f"text={text}"],
                          check=True, capture_output=True, text=True).stdout
    return NOTES_PAGE.replace("{notes}", html.strip())

ns = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", ns)
rss = ET.Element("rss", version="2.0")
channel = ET.SubElement(rss, "channel")
ET.SubElement(channel, "title").text = "Fst"
item = ET.SubElement(channel, "item")
ET.SubElement(item, "title").text = version
ET.SubElement(item, "pubDate").text = email.utils.format_datetime(datetime.datetime.now(datetime.timezone.utc))
ET.SubElement(item, f"{{{ns}}}minimumSystemVersion").text = info["LSMinimumSystemVersion"]
ET.SubElement(item, "description").text = release_notes(version)
ET.SubElement(item, "enclosure", {
    "url": url, "length": str(archive.stat().st_size), "type": "application/octet-stream",
    f"{{{ns}}}version": info["CFBundleVersion"], f"{{{ns}}}shortVersionString": version,
    f"{{{ns}}}edSignature": signature,
})
ET.indent(rss)
ET.ElementTree(rss).write("dist/appcast.xml", encoding="utf-8", xml_declaration=True)
sha = hashlib.file_digest(archive.open("rb"), "sha256").hexdigest()
Path("dist/fst.rb").write_text(f'''cask "fst" do
  version "{version}"
  sha256 "{sha}"

  url "https://github.com/mikker/Fst/releases/download/v#{{version}}/Fst.app.zip"
  name "Fst"
  desc "Fast, minimal native text editor"
  homepage "https://github.com/mikker/Fst"
  auto_updates true
  depends_on macos: ">= :sonoma"

  livecheck do
    url "https://github.com/mikker/Fst/releases/latest/download/appcast.xml"
    strategy :sparkle, &:short_version
  end

  app "Fst.app"

  zap trash: "~/Library/Containers/com.mikker.Fst"
end
''')
