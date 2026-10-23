# Roblox .rbxmx/.rbxlx (XML) ফাইল থেকে সব Script বের করে আর একটা outline বানায়।
# ব্যবহার: python3 tools/extract_rbxmx.py "<file>.rbxmx" <out_dir>
import sys, os, re
import xml.etree.ElementTree as ET
src, out = sys.argv[1], sys.argv[2]
root = ET.parse(src).getroot()
SCRIPTS = {"Script","LocalScript","ModuleScript"}
SKIP_OUTLINE = {"Weld","ManualWeld","WeldConstraint","UIPadding","UICorner","UIListLayout","UIStroke","UIGradient","UIGridLayout","UIFlexItem","Decal","Texture","BlockMesh","CylinderMesh","TextLabel","Frame","ImageLabel","ImageButton","TextButton","UITextSizeConstraint","UIAspectRatioConstraint","Part","UnionOperation","MeshPart"}
outline = open(os.path.join(out, "outline.txt"), "w")
index = open(os.path.join(out, "scripts_index.txt"), "w")
def prop(item, name):
    p = item.find("Properties")
    if p is None: return None
    for c in p:
        if c.get("name") == name: return c
    return None
def safe(s): return re.sub(r'[^A-Za-z0-9_.-]', '_', s) or "_"
def walk(item, path, depth):
    cls = item.get("class")
    n = prop(item, "Name"); name = n.text if n is not None and n.text else cls
    p = path + [name]
    if cls not in SKIP_OUTLINE:
        extra = ""
        if cls in SCRIPTS:
            rc = prop(item, "RunContext"); dis = prop(item, "Disabled")
            extra = f" RunContext={rc.text if rc is not None else '-'} Disabled={dis.text if dis is not None else '-'}"
        outline.write("  "*depth + f"{name} [{cls}]{extra}\n")
    if cls in SCRIPTS:
        s = prop(item, "Source"); code = (s.text or "") if s is not None else ""
        rel = os.path.join(*[safe(x) for x in p]) + f".{cls}.lua"
        fp = os.path.join(out, "scripts", rel)
        k = 2
        while os.path.exists(fp):
            fp = os.path.join(out, "scripts", rel[:-4] + f"_{k}.lua"); k += 1
        rel = os.path.relpath(fp, os.path.join(out, "scripts"))
        os.makedirs(os.path.dirname(fp), exist_ok=True)
        open(fp, "w").write(code)
        index.write(f"{len(code):8d}  {rel}\n")
    for ch in item.findall("Item"):
        walk(ch, p, depth+1)
for it in root.findall("Item"):
    walk(it, [], 0)
