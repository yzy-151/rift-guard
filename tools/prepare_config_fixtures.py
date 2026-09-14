"""Generate adversarial input fixtures from the authored workbook; never edit user content."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import xml.etree.ElementTree as ET
import shutil
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "content/game_config.xlsx"
OUT = ROOT / "research/m5-fixtures"
NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
def q(tag): return "{"+NS+"}"+tag
with ZipFile(SOURCE) as z:
    original = {n: z.read(n) for n in z.namelist()}
rels = ET.fromstring(original["xl/_rels/workbook.xml.rels"])
targets = {r.attrib["Id"]: (r.attrib["Target"].lstrip("/") if r.attrib["Target"].startswith("/") else "xl/"+r.attrib["Target"]) for r in rels}
book = ET.fromstring(original["xl/workbook.xml"])
sheet_paths = {s.attrib["name"]: targets[s.attrib["{"+REL+"}id"]] for s in book.find(q("sheets"))}
def change(data, sheet, cell, value, formula=False):
    part = sheet_paths[sheet]
    tree = ET.fromstring(data[part])
    rows = tree.find(q("sheetData"))
    rn = int("".join(x for x in cell if x.isdigit()))
    row = next((x for x in rows if x.attrib.get("r") == str(rn)), None)
    if row is None:
        row = ET.SubElement(rows, q("row"), {"r":str(rn)})
    node = next((x for x in row if x.attrib.get("r") == cell), None)
    if node is None:
        node = ET.SubElement(row, q("c"), {"r":cell})
    for child in list(node): node.remove(child)
    if formula:
        node.attrib.pop("t", None)
        ET.SubElement(node,q("f")).text = "1+0"
        ET.SubElement(node,q("v")).text = "1"
    elif isinstance(value, (int,float)):
        node.attrib.pop("t", None)
        ET.SubElement(node,q("v")).text = str(value)
    else:
        node.attrib["t"] = "inlineStr"
        ET.SubElement(ET.SubElement(node,q("is")),q("t")).text = str(value)
    data[part] = ET.tostring(tree, encoding="utf-8", xml_declaration=True)
def write(name, data):
    folder = OUT/name
    folder.mkdir(parents=True,exist_ok=True)
    with ZipFile(folder/"game_config.xlsx","w",ZIP_DEFLATED) as z:
        for path,payload in data.items(): z.writestr(path,payload)
    return folder
data=dict(original)
for cell,value in {"D5":"测试编剧","E5":"Excel 自动加载验证","F5":"qa_external","G5":"right","H5":900,"I5":100,"J5":0.6,"K5":1,"L5":"","R5":"none","A30":1,"B30":"extra_scene","C30":1,"D30":"额外角色","E30":"新增段落预览","F30":"qa_external"}.items(): change(data,"对话",cell,value)
for cell,value in {"A11":"qa_external","B11":"images/portrait.png","C11":"测试外部PNG","D11":"立绘"}.items():change(data,"图片资源",cell,value)
for cell,value in {"B5":60,"C5":450,"D5":1000,"E5":240,"H8":"测试继续"}.items():change(data,"UI",cell,value)
change(data,"图片资源","A12","qa_button")
change(data,"图片资源","B12","res://assets/effects/heal-sheet.png")
change(data,"UI","F8","qa_button")
change(data,"UI","G8","keep")
folder=write("modified",data)
(folder/"images").mkdir(exist_ok=True)
shutil.copyfile(ROOT/"game/assets/portraits/saria.png", folder/"images/portrait.png")
for name,sheet,cell,value in [("missing_image","图片资源","B5","images/not-found.png"),("invalid_number","对话","J5","large")]:
    data=dict(original);change(data,sheet,cell,value);write(name,data)
data=dict(original)
for c,v in {"A30":1,"B30":"opening","C30":1,"D30":"重复","E30":"重复顺序","F30":"saria"}.items():change(data,"对话",c,v)
write("duplicate_order",data)
data=dict(original);change(data,"对话","J5",1,formula=True);write("formula",data)
data=dict(original)
for row in range(5,9):change(data,"对话","A"+str(row),0)
write("disabled_opening",data)
data=dict(original)
part=sheet_paths["对话"]
tree=ET.fromstring(data[part])
kept=[x for x in tree.find(q("sheetData")) if int(x.attrib.get("r","0"))<=5]
data[part]=(('<worksheet xmlns="'+NS+'"><sheetData>').encode()+b"".join(ET.tostring(x,encoding="utf-8") for x in kept)+b'<row r="6"><c r="A6">')
write("truncated_xml",data)
print("Created 7 test fixture directories; original workbook unchanged.")
