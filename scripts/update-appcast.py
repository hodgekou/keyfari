#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Adds one release to site/appcast.xml, the feed the app reads to find updates.

Usage: scripts/update-appcast.py <version> <path to the disk image> <EdDSA signature>

The signature comes from Sparkle's sign_update, run with the project's private key. This
script never sees that key. The entry for a version that is already in the feed is replaced.
"""

import base64
import datetime
import email.utils
import html
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FEED = os.path.join(ROOT, "site", "appcast.xml")
RELEASES = "https://github.com/hodgekou/keyfari/releases"
MINIMUM_SYSTEM = "14.0"
ITEM = re.compile(r"    <item>.*?</item>\n", re.S)


def fail(message):
    sys.exit(f"error: {message}")


def changes(version):
    """The section of CHANGELOG.md for this version, as a little HTML."""
    with open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8") as changelog:
        lines = changelog.read().splitlines()
    heading = f"## [{version}]"
    start = next((i for i, line in enumerate(lines) if line.startswith(heading)), None)
    if start is None:
        fail(f"CHANGELOG.md has no section for {version}")
    out, in_list = [], False
    for line in lines[start + 1:]:
        if line.startswith("## ["):
            break
        if line.startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            text = html.escape(line[2:])
            text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
            out.append(f"<li>{text}</li>")
            continue
        if in_list:
            out.append("</ul>")
            in_list = False
        if line.startswith("### "):
            out.append(f"<h3>{html.escape(line[4:])}</h3>")
        elif line.strip():
            out.append(f"<p>{html.escape(line)}</p>")
    if in_list:
        out.append("</ul>")
    return "\n".join(out)


def item(version, length, signature, now):
    # "]]>" cannot appear inside a CDATA section; the changelog is escaped HTML, so it cannot occur.
    return f"""    <item>
      <title>{version}</title>
      <pubDate>{email.utils.format_datetime(now)}</pubDate>
      <link>{RELEASES}/tag/v{version}</link>
      <sparkle:version>{version}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{MINIMUM_SYSTEM}</sparkle:minimumSystemVersion>
      <description><![CDATA[
{changes(version)}
]]></description>
      <enclosure url="{RELEASES}/download/v{version}/Keyfari-{version}.dmg" sparkle:edSignature="{signature}" length="{length}" type="application/octet-stream"/>
    </item>
"""


def main(arguments):
    if len(arguments) != 3:
        fail(__doc__.strip().splitlines()[2])
    version, image, signature = arguments

    # Everything that ends up in the feed is checked first.
    if not re.fullmatch(r"\d{1,6}\.\d{1,6}\.\d{1,6}", version):
        fail(f"{version!r} is not a version of the form 1.2.3")
    try:
        if len(base64.b64decode(signature, validate=True)) != 64:
            raise ValueError
    except ValueError:
        fail("the signature is not a base64 EdDSA signature of 64 bytes")
    if not os.path.isfile(image):
        fail(f"{image} is not a file")
    if os.path.basename(image) != f"Keyfari-{version}.dmg":
        fail(f"the disk image must be named Keyfari-{version}.dmg")

    entry = item(version, os.path.getsize(image), signature, datetime.datetime.now(datetime.timezone.utc))

    if os.path.exists(FEED):
        with open(FEED, encoding="utf-8") as feed:
            text = feed.read()
    else:
        text = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Keyfari</title>
    <link>{RELEASES}</link>
    <description>Releases of Keyfari.</description>
    <language>en</language>
  </channel>
</rss>
"""
    # A release that is published again replaces its entry.
    same = re.compile(rf"<sparkle:version>{re.escape(version)}</sparkle:version>")
    text = ITEM.sub(lambda match: "" if same.search(match.group(0)) else match.group(0), text)

    # Newest first: right after the channel's own description.
    marker = "<language>en</language>\n"
    if marker not in text:
        fail(f"{FEED} does not look like this project's feed")
    text = text.replace(marker, marker + entry, 1)

    with open(FEED, "w", encoding="utf-8") as feed:
        feed.write(text)
    print(f"Added {version} to {os.path.relpath(FEED, ROOT)}")


if __name__ == "__main__":
    main(sys.argv[1:])
