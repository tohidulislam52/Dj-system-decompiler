# fixed/ ফোল্ডারের স্ক্রিপ্টগুলো .rbxmx ফাইলের ভেতরে বসায়, যাতে দুটো সবসময় এক থাকে।
# ব্যবহার: python3 tools/sync_sources.py <in.rbxmx> <repo> <out.rbxmx>
import sys
import xml.etree.ElementTree as ET
src, repo, out = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(src, encoding="utf-8").read()
root = ET.fromstring(text)

def name(it):
    for c in it.find("Properties"):
        if c.get("name") == "Name": return c.text
def ref(path):
    it = root.find("Item")
    for p in path:
        found = [c for c in it.findall("Item") if name(c) == p]
        assert len(found) == 1, (path, p, len(found))
        it = found[0]
    return it.get("referent")

MAP = {
    ("RS", "DJSystem", "Modules", "AdminModule"): "ReplicatedStorage/DJSystem/Modules/AdminModule.lua",
    ("SSS", "DJSystem", "DJAuthority"): "ServerScriptService/DJSystem/DJAuthority.lua",
    ("SSS", "DJSystem", "Lights", "GLightSyncServer"): "ServerScriptService/DJSystem/Lights/GLightSyncServer.server.lua",
    ("SSS", "DJSystem", "Pyro", "QPyroSyncServer"): "ServerScriptService/DJSystem/Pyro/QPyroSyncServer.server.lua",
    ("SSS", "DJSystem", "Music", "MusicServer"): "ServerScriptService/DJSystem/Music/MusicServer.server.lua",
    ("SPS", "DJSystem", "Controls", "TopBar"): "StarterPlayerScripts/DJSystem/Controls/TopBar.client.lua",
    ("SPS", "DJSystem", "Controls", "QPyroControlPanel"): "StarterPlayerScripts/DJSystem/Controls/QPyroControlPanel.client.lua",
    ("SPS", "DJSystem", "Controls", "DJControlLock"): "StarterPlayerScripts/DJSystem/Controls/DJControlLock.client.lua",
    ("SPS", "DJSystem", "Music", "NotifHandler"): "StarterPlayerScripts/DJSystem/Music/NotifHandler.client.lua",
    ("SGUI", "GLightsControlPanel", "GLightsControlScript"): "StarterGui/GLightsControlPanel/GLightsControlScript.client.lua",
    ("Ws", "QPyro", "Q-Tech Premium", "MainFolder", "MainScript"): "Workspace/QPyro/Q-Tech Premium/MainFolder/MainScript.server.lua",
    ("Ws", "GLights", "GlobalSettings"): "Workspace/GLights/GlobalSettings.lua",
}
# MusikGui-তে একই নামের দুটো MusicClient আছে (একটা Disabled), তাই referent দিয়ে আলাদা করা
mg = [c for c in root.find("Item").findall("Item") if name(c) == "SGUI"][0]
mg = [c for c in mg.findall("Item") if name(c) == "MusikGui"][0]
clients = [c for c in mg.findall("Item") if name(c) == "MusicClient"]
assert len(clients) == 2
REFS = {ref(p): rel for p, rel in MAP.items()}
for c in clients:
    disabled = any(p.get("name") == "Disabled" and p.text == "true" for p in c.find("Properties"))
    REFS[c.get("referent")] = "StarterGui/MusikGui/MusicClient (Disabled).client.lua" if disabled else "StarterGui/MusikGui/MusicClient.client.lua"

OPEN = '<ProtectedString name="Source"><![CDATA['
CLOSE = ']]></ProtectedString>'
changed = 0
for r, rel in REFS.items():
    code = open(f"{repo}/fixed/{rel}", encoding="utf-8").read().rstrip("\n")
    assert "]]>" not in code
    start = text.index(f'referent="{r}">')
    s = text.index(OPEN, start) + len(OPEN)
    nxt = text.find("<Item ", start)
    assert nxt == -1 or s < nxt, rel
    e = text.index(CLOSE, s)
    if text[s:e].rstrip("\n") != code:
        changed += 1
        print("updated", rel)
    text = text[:s] + code + text[e:]
open(out, "w", encoding="utf-8").write(text)
ET.fromstring(text)
print(f"{len(REFS)} scripts synced, {changed} changed, xml ok")
