#!/usr/bin/env python3
"""Run the Bobux Obby scripts against a strict mock of the Roblox API.

usage: python3 tools/test/run.py path/to/globalTypes.d.luau
(the definitions file comes from the luau-lsp project)
"""
import os, re, sys
import lupa.luajit21 as lupa

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

def parse_api(path):
    classes, enums, cur, cur_enum = {}, {}, None, None
    for line in open(path, encoding="utf-8"):
        m = re.match(r"declare extern type (\w+)(?: extends (\w+))? with", line)
        if m:
            name, parent = m.group(1), m.group(2)
            if name.endswith("_INTERNAL") and parent == "Enum":
                cur_enum, cur = name[4:-9], None
                enums[cur_enum] = []
            else:
                cur, cur_enum = name, None
                classes[name] = {"parent": parent, "members": {}}
            continue
        if line.startswith("end"):
            cur = cur_enum = None
            continue
        s = line.strip()
        if cur_enum:
            m = re.match(r"(\w+): Enum", s)
            if m: enums[cur_enum].append(m.group(1))
        elif cur:
            m = re.match(r"function (\w+)\(", s)
            if m:
                classes[cur]["members"][m.group(1)] = "method"; continue
            m = re.match(r"(\w+): (.+)$", s)
            if m:
                classes[cur]["members"][m.group(1)] = "signal" if "RBXScriptSignal" in m.group(2) else "prop"
    return classes, enums

def lua_api(classes, enums):
    out = ["API_CLASSES = {}"]
    for name, c in classes.items():
        members = ",".join('%s="%s"' % (k, v) for k, v in c["members"].items() if re.match(r"^[A-Za-z_]\w*$", k) and k not in ("end", "function", "and", "or", "not", "nil", "true", "false", "local", "if", "then", "else", "for", "in", "do", "while", "repeat", "until", "return", "break", "elseif"))
        out.append('API_CLASSES["%s"] = {parent=%s, members={%s}}' % (name, ('"%s"' % c["parent"]) if c["parent"] else "nil", members))
    out.append("API_ENUMS = {}")
    for name, items in enums.items():
        out.append('API_ENUMS["%s"] = {%s}' % (name, ",".join('["%s"]=%d' % (it, i) for i, it in enumerate(items))))
    return "\n".join(out)

def classify(fn):
    for suf, cn in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")):
        if fn.endswith(suf): return fn[:-len(suf)], cn
    return None, None

def main():
    classes, enums = parse_api(sys.argv[1])
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(lua_api(classes, enums))
    lua.execute(open(os.path.join(HERE, "mock.lua"), encoding="utf-8").read())
    g = lua.globals()
    g.SOURCES = lua.table()
    new = g.NEW
    def build(path, name, parent):
        if os.path.isfile(path):
            base, cn = classify(os.path.basename(path))
            inst = new(cn, base); inst.Parent = parent
            g.SOURCES[inst] = lua.table(open(path, encoding="utf-8").read(), os.path.relpath(path, ROOT))
            return inst
        entries = sorted(os.listdir(path))
        init = next((e for e in entries if classify(e)[0] == "init"), None)
        if init:
            inst = new(classify(init)[1], name)
            g.SOURCES[inst] = lua.table(open(os.path.join(path, init), encoding="utf-8").read(), os.path.relpath(os.path.join(path, init), ROOT))
        else:
            inst = new("Folder", name)
        inst.Parent = parent
        for e in entries:
            if e != init: build(os.path.join(path, e), e, inst)
        return inst
    S = g.SERVICES
    build(os.path.join(ROOT, "src/shared"), "Shared", S("ReplicatedStorage"))
    build(os.path.join(ROOT, "src/server"), "Server", S("ServerScriptService"))
    sps = new("StarterPlayerScripts", "StarterPlayerScripts"); sps.Parent = S("StarterPlayer")
    build(os.path.join(ROOT, "src/client"), "Client", sps)
    lua.execute(open(os.path.join(HERE, "scenario.lua"), encoding="utf-8").read())

if __name__ == "__main__":
    main()
