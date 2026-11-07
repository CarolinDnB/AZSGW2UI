"""Finds closures that use a numeric for loop variable directly (Lua 5.0, the game's version, shares that variable between
all the closures of the loop; copy it to a local inside the body first). Indent based: the files use one tab per level.
usage: python3 lint_loops.py [files...]   (default: every .lua file of ../AZSGW2UI)"""
import glob, os, re, sys

def indent(s):
    return len(s) - len(s.lstrip("\t"))

def scan(path):
    lines = open(path, encoding="utf-8").read().split("\n")
    bad = []
    for n, line in enumerate(lines):
        m = re.match(r"^(\t*)for\s+(\w+)\s*=", line) or re.match(r"^(\t*)for\s+(\w+)\s*,\s*(\w+)\s+in\s", line)
        if not m:
            continue
        base = len(m.group(1))
        names = [g for g in m.groups()[1:] if g]
        k = n + 1
        body = []
        while k < len(lines):
            if lines[k].strip() and indent(lines[k]) <= base:
                break
            body.append((k, lines[k]))
            k += 1
        # lines that sit inside a function defined in the body
        j = 0
        while j < len(body):
            k0, txt = body[j]
            if re.search(r"\bfunction\s*\w*\s*\(", txt):
                fi = indent(txt)
                inner = [(k0, txt)]
                j += 1
                while j < len(body) and ( not body[j][1].strip() or indent(body[j][1]) > fi ):
                    inner.append(body[j]); j += 1
                if j < len(body):
                    inner.append(body[j]); j += 1          # the closing line
                for q, (kk, t) in enumerate(inner):
                    code = t.split("--")[0]
                    if q == 0:
                        code = code[code.find("function"):]       # what comes before the function on that line is not inside it
                    for nm in names:
                        # a parameter of the function with the same name hides the loop variable
                        if re.search(r"\bfunction\s*\w*\s*\([^)]*\b%s\b" % nm, inner[0][1]):
                            continue
                        if re.search(r"\b%s\b" % nm, code):
                            bad.append((path, kk + 1, nm, t.strip()))
                continue
            j += 1
    return bad

files = sys.argv[1:] or sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "AZSGW2UI", "*.lua")))
found = []
for f in files:
    found += scan(f)
for p, ln, nm, t in found:
    print("%s:%d: closure uses loop variable '%s': %s" % (os.path.basename(p), ln, nm, t[:110]))
print("%d place(s)" % len(found))
sys.exit(1 if found else 0)
