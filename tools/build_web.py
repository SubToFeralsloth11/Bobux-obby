#!/usr/bin/env python3
"""Bundle the browser game into one self-contained file: docs/index.html.

It inlines three.js and the game scripts, so the result works by
double-clicking it (no server, no internet) and on GitHub Pages.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
read = lambda name: open(os.path.join(ROOT, "web", name), encoding="utf-8").read()

scripts = "".join("<script>\n%s\n</script>\n" % read(n).replace("</script", "<\\/script") for n in ("three.min.js", "level.js", "game.js"))
html = read("index.html").replace("<!--SCRIPTS-->", scripts)
out = os.path.join(ROOT, "docs", "index.html")
with open(out, "w", encoding="utf-8") as handle:
    handle.write(html)
print("Wrote %s (%d KB)" % (out, len(html) // 1024))
