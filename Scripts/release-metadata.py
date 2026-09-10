#!/usr/bin/env python3
"""Generate the feed and cask from the exact signed release archive."""
import datetime
import email.utils
import hashlib
from pathlib import Path
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

version = sys.argv[1]
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise SystemExit("Expected version X.Y.Z")
archive = Path("dist/Fst.app.zip")
info = plistlib.loads(Path("build/export/Fst.app/Contents/Info.plist").read_bytes())
assert info["CFBundleShortVersionString"] == version
signature = Path("dist/signature.txt").read_text().strip()
assert re.fullmatch(r"[A-Za-z0-9+/]{86}==", signature), "Invalid Ed25519 signature"
url = f"https://github.com/mikker/Fst/releases/download/v{version}/Fst.app.zip"
ns = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", ns)
rss = ET.Element("rss", version="2.0")
channel = ET.SubElement(rss, "channel")
ET.SubElement(channel, "title").text = "Fst"
item = ET.SubElement(channel, "item")
ET.SubElement(item, "title").text = version
ET.SubElement(item, "pubDate").text = email.utils.format_datetime(datetime.datetime.now(datetime.timezone.utc))
ET.SubElement(item, f"{{{ns}}}minimumSystemVersion").text = info["LSMinimumSystemVersion"]
ET.SubElement(item, f"{{{ns}}}releaseNotesLink").text = f"https://github.com/mikker/Fst/releases/tag/v{version}"
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
