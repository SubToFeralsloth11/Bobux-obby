#!/usr/bin/env python3
"""Build BobuxObby.rbxlx (a Roblox Studio place file) from the src/ folder.

No Rojo needed: just run  python3 tools/build_place.py
File naming follows Rojo's rules:
  Name.server.luau -> Script, Name.client.luau -> LocalScript,
  Name.luau -> ModuleScript, a folder with init.luau -> ModuleScript with children.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
counter = [0]


def ref():
    counter[0] += 1
    return "RBX%d" % counter[0]


def esc(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(class_name, name, props="", children=""):
    return '<Item class="%s" referent="%s"><Properties><string name="Name">%s</string>%s</Properties>%s</Item>\n' % (
        class_name, ref(), esc(name), props, children)


def script(class_name, name, path, children=""):
    with open(path, encoding="utf-8") as handle:
        source = handle.read()
    return item(class_name, name, '<ProtectedString name="Source">%s</ProtectedString>' % cdata(source), children)


def classify(filename):
    for suffix, class_name in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")):
        if filename.endswith(suffix):
            return filename[: -len(suffix)], class_name
    return None, None


def build(path, name):
    """Turn a file or folder into instance XML."""
    if os.path.isfile(path):
        base, class_name = classify(os.path.basename(path))
        return script(class_name, base, path) if class_name else ""
    entries = sorted(os.listdir(path))
    init = next((e for e in entries if classify(e)[0] == "init"), None)
    children = "".join(build(os.path.join(path, e), e) for e in entries if e != init)
    if init:
        return script(classify(init)[1], name, os.path.join(path, init), children)
    return item("Folder", name, "", children)


def main():
    out = os.path.join(ROOT, "BobuxObby.rbxlx")
    src = os.path.join(ROOT, "src")
    body = ""
    body += item("Workspace", "Workspace", '<bool name="StreamingEnabled">false</bool>')
    body += item("Players", "Players", '<bool name="CharacterAutoLoads">false</bool>')
    body += item("Lighting", "Lighting", '<token name="Technology">4</token>')
    body += item("ReplicatedStorage", "ReplicatedStorage", "", build(os.path.join(src, "shared"), "Shared"))
    body += item("ServerScriptService", "ServerScriptService", "", build(os.path.join(src, "server"), "Server"))
    body += item("StarterPlayer", "StarterPlayer", "",
                 item("StarterPlayerScripts", "StarterPlayerScripts", "", build(os.path.join(src, "client"), "Client")))
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n' + body + "</roblox>\n")
    with open(out, "w", encoding="utf-8") as handle:
        handle.write(xml)
    print("Wrote %s (%d instances, %d KB)" % (out, counter[0], len(xml) // 1024))


if __name__ == "__main__":
    sys.exit(main())
