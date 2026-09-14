import json
import time
import urllib.request
import uuid


server = "http://127.0.0.1:8188"
prompt = {
    "1": {
        "class_type": "LoadImage",
        "inputs": {"image": "furina-attack-style-match-v1-source.png"},
    },
    "2": {
        "class_type": "BiRefNetRMBG",
        "inputs": {
            "image": ["1", 0],
            "model": "BiRefNet-general",
            "mask_blur": 1,
            "mask_offset": 1,
            "invert_output": False,
            "refine_foreground": True,
            "background": "Alpha",
            "background_color": "#000000",
        },
    },
    "3": {
        "class_type": "SaveImage",
        "inputs": {
            "images": ["2", 0],
            "filename_prefix": "ComfyUI_Alpha/RiftGuard_M10/furina_attack_style_match_v1",
        },
    },
}
request = urllib.request.Request(
    server + "/prompt",
    json.dumps({"prompt": prompt, "client_id": str(uuid.uuid4())}).encode("utf-8"),
    {"Content-Type": "application/json"},
)
with urllib.request.urlopen(request, timeout=30) as response:
    prompt_id = json.load(response)["prompt_id"]
print("queued=" + prompt_id, flush=True)
for _ in range(120):
    time.sleep(2)
    with urllib.request.urlopen(server + "/history/" + prompt_id, timeout=30) as response:
        history = json.load(response)
    if prompt_id not in history:
        continue
    item = history[prompt_id]
    if item.get("status", {}).get("status_str") == "error":
        raise RuntimeError(json.dumps(item["status"], ensure_ascii=False))
    images = item.get("outputs", {}).get("3", {}).get("images", [])
    print(json.dumps(images, ensure_ascii=False))
    break
else:
    raise TimeoutError("RMBG timed out")
