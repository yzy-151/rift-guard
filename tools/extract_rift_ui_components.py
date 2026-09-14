"""Extract reusable transparent UI pieces from the supplied 1920x1080 sheets."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "game" / "assets" / "ui" / "rift_v2"
OUTPUT = SOURCE / "components"

PIECES = {
    "choice_gray.png": ("buff_select.png", (38, 577, 417, 648)),
    "choice_red.png": ("buff_select.png", (432, 576, 814, 648)),
    "choice_cyan.png": ("buff_select.png", (830, 576, 1214, 648)),
    "buff_card_gray.png": ("buff_select.png", (38, 173, 409, 561)),
    "buff_card_red.png": ("buff_select.png", (434, 172, 810, 565)),
    "buff_card_cyan.png": ("buff_select.png", (835, 173, 1205, 561)),
    "mode_card_gray.png": ("mode_select.png", (46, 245, 667, 612)),
    "mode_card_red.png": ("mode_select.png", (684, 245, 1306, 612)),
    "mode_card_art.png": ("mode_select.png", (1336, 248, 1872, 586)),
    "mode_header.png": ("mode_select.png", (46, 21, 519, 232)),
    "mode_checkpoint.png": ("mode_select.png", (46, 887, 1246, 1042)),
    "mission_card_gray.png": ("mission_select.png", (34, 197, 511, 500)),
    "mission_card_red.png": ("mission_select.png", (519, 188, 1009, 506)),
    "mission_card_locked.png": ("mission_select.png", (1016, 196, 1497, 502)),
    "mission_header.png": ("mission_select.png", (26, 20, 613, 174)),
    "mission_endless.png": ("mission_select.png", (34, 925, 1572, 1048)),
    "hud_logo.png": ("right_column_hud.png", (53, 39, 434, 166)),
    "hud_buff_frame.png": ("right_column_hud.png", (57, 211, 434, 297)),
    "hud_hero_red.png": ("right_column_hud.png", (487, 371, 1022, 524)),
    "hud_hero_gray.png": ("right_column_hud.png", (1063, 368, 1551, 527)),
    "hud_skill_red.png": ("right_column_hud.png", (489, 557, 687, 761)),
    "hud_skill_gray.png": ("right_column_hud.png", (730, 551, 935, 762)),
    "hud_ultimate_red.png": ("right_column_hud.png", (994, 556, 1191, 760)),
    "hud_ultimate_gray.png": ("right_column_hud.png", (1238, 550, 1440, 762)),
    "hud_topbar.png": ("right_column_hud.png", (524, 45, 1447, 99)),
}


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    cache = {}
    for name, (sheet, box) in PIECES.items():
        image = cache.setdefault(sheet, Image.open(SOURCE / sheet).convert("RGBA"))
        image.crop(box).save(OUTPUT / name)
    print(f"extracted {len(PIECES)} UI pieces to {OUTPUT}")


if __name__ == "__main__":
    main()
