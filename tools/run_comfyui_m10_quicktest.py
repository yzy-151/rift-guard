import json
import time
import urllib.request
import uuid


SERVER = "http://127.0.0.1:8188"


def link(node: str, output: int):
    return [node, output]


prompt = {
    "1": {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {"ckpt_name": "WAI_NSFW-illustrious-SDXL_v9.safetensors"},
    },
    "2": {
        "class_type": "LoraLoader",
        "inputs": {
            "model": link("1", 0),
            "clip": link("1", 1),
            "lora_name": "SDXL_IL\\原神\\芙宁娜Fenina_FeninaV1.safetensors",
            "strength_model": 0.82,
            "strength_clip": 0.82,
        },
    },
    "3": {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "clip": link("2", 1),
            "text": (
                "masterpiece, game sprite, full body, solo, Furina, chibi, 2.5 heads tall, "
                "white short hair, blue eyes, small dark blue top hat, navy white ornate costume, "
                "three-quarter view, water attack, bent knees, articulated limbs, cel shading, white background"
            ),
        },
    },
    "4": {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "clip": link("2", 1),
            "text": (
                "lowres, blurry, realistic, tall, scenery, text, watermark, multiple characters, "
                "extra limbs, missing limbs, malformed hands, cropped, different outfit, checkerboard"
            ),
        },
    },
    "5": {
        "class_type": "EmptyLatentImage",
        "inputs": {"width": 640, "height": 640, "batch_size": 1},
    },
    "6": {
        "class_type": "KSampler",
        "inputs": {
            "model": link("2", 0),
            "seed": 9062026,
            "steps": 18,
            "cfg": 5.0,
            "sampler_name": "dpmpp_2m_sde",
            "scheduler": "karras",
            "positive": link("3", 0),
            "negative": link("4", 0),
            "latent_image": link("5", 0),
            "denoise": 1.0,
        },
    },
    "7": {
        "class_type": "VAEDecode",
        "inputs": {"samples": link("6", 0), "vae": link("1", 2)},
    },
    "8": {
        "class_type": "BiRefNetRMBG",
        "inputs": {
            "image": link("7", 0),
            "model": "BiRefNet-general",
            "mask_blur": 1,
            "mask_offset": 1,
            "invert_output": False,
            "refine_foreground": True,
            "background": "Alpha",
            "background_color": "#000000",
        },
    },
    "9": {
        "class_type": "SaveImage",
        "inputs": {
            "images": link("8", 0),
            "filename_prefix": "ComfyUI_Alpha/RiftGuard_M10/Furina_quick_style",
        },
    },
}


body = json.dumps({"prompt": prompt, "client_id": str(uuid.uuid4())}).encode("utf-8")
request = urllib.request.Request(
    SERVER + "/prompt", body, {"Content-Type": "application/json"}
)
with urllib.request.urlopen(request, timeout=30) as response:
    queued = json.load(response)

prompt_id = queued["prompt_id"]
print(f"queued={prompt_id}", flush=True)

for _ in range(180):
    time.sleep(2)
    with urllib.request.urlopen(SERVER + "/history/" + prompt_id, timeout=30) as response:
        history = json.load(response)
    if prompt_id not in history:
        continue
    item = history[prompt_id]
    status = item.get("status", {})
    if status.get("status_str") == "error":
        raise RuntimeError(json.dumps(status, ensure_ascii=False))
    images = []
    for output in item.get("outputs", {}).values():
        images.extend(output.get("images", []))
    print(json.dumps({"prompt_id": prompt_id, "images": images}, ensure_ascii=False))
    break
else:
    raise TimeoutError("ComfyUI quick test timed out")
