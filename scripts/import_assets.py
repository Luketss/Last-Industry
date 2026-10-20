#!/usr/bin/env python3
"""Downloads the third-party asset packs (OpenGameArt.org) and rebuilds assets/.

Every pack used is listed in SOURCES with its page, author and licence; the
selection below decides which files from each pack end up in the game. The
output is committed, so this only needs to run when the selection changes:

    python3 scripts/import_assets.py            # downloads to .asset_cache/
    python3 scripts/import_assets.py --cache D  # reuse already downloaded packs

Requires Pillow and ffmpeg. Kenney's 3D kits share a pastel colour atlas; it is
recoloured here into the game's rusty, desaturated palette so the models match
the post-apocalyptic look (see recolor()).
"""
import argparse
import colorsys
import json
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image

OGA = "https://opengameart.org/sites/default/files/"
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets"

# id -> (page, file, author, licence)
SOURCES = {
    "factory": ("https://opengameart.org/content/factory-kit", "kenney_factory-kit_3.0.zip", "Kenney", "CC0"),
    "td": ("https://opengameart.org/content/tower-defense-kit", "kenney_tower-defense-kit_1.zip", "Kenney", "CC0"),
    "city": ("https://opengameart.org/content/city-kit-industrial", "kenney_city-kit-industrial_2.0.zip", "Kenney", "CC0"),
    "ui": ("https://opengameart.org/content/ui-pack-sci-fi", "kenney_ui-pack-scifi.zip", "Kenney", "CC0"),
    "icons": ("https://opengameart.org/content/game-icons", "Kenney_gameIcons.zip", "Kenney", "CC0"),
    "scifi_sfx": ("https://opengameart.org/content/sci-fi-sounds", "sci-fi_sounds.zip", "Kenney", "CC0"),
    "ui_sfx": ("https://opengameart.org/content/interface-sounds", "kenney_interfaceSounds.zip", "Kenney", "CC0"),
    "scifi_items": ("https://opengameart.org/content/different-sci-fi-item-icons", "Different-Sci-Fi-Item-Icons.zip", "CraftPix.net", "OGA-BY 3.0"),
    "apoc_icons": ("https://opengameart.org/content/free-set-of-10-post-apocalypse-icons", "Post-apocalypse%20Game-Free-icons-pack1.zip", "CraftPix.net", "OGA-BY 3.0"),
    "monsters": ("https://opengameart.org/content/50-monsters-pack-3d", "50_monsters_pack_3d_version_1.0.zip", "isaiah658", "CC0"),
    "m_menu": ("https://opengameart.org/content/tragic-ambient-main-menu", "ambientmain_0.ogg", "HaelDB", "CC0"),
    "m_empty": ("https://opengameart.org/content/emptycity-background-music", "EmptyCity_0.ogg", "yd", "CC0"),
    "m_factory": ("https://opengameart.org/content/factory-ambiance", "Factory_0.ogg", "yd", "CC0"),
    "m_scavenger": ("https://opengameart.org/content/lone-scavenger", "lone_scavenger_4.mp3", "vitalezzz", "CC0"),
    "m_iron": ("https://opengameart.org/content/iron-wasteland", "Iron%20wasteland.ogg", "Alexandr Zhelanov", "CC-BY 4.0"),
    "m_boss": ("https://opengameart.org/content/boss-battle-9-metal", "boss_battle_9_metal_loop.wav", "nene", "CC0"),
    "m_fight": ("https://opengameart.org/content/cyborg-factory-fight-theme", "Cyborg_Factory_Fight_0.ogg", "GTDStudio (Palrom)", "OGA-BY 3.0"),
}

TITLES = {
    "factory": "Factory Kit", "td": "Tower Defense Kit", "city": "City Kit (Industrial)", "ui": "UI Pack - Sci-Fi",
    "icons": "Game Icons", "monsters": "50+ Monsters Pack 3D",
    "scifi_items": "Different Sci-Fi Item Icons", "apoc_icons": "Free Set of 10 Post-apocalypse Icons", "scifi_sfx": "Sci-Fi Sounds", "ui_sfx": "Interface Sounds",
    "m_menu": "Tragic ambient main menu", "m_empty": "EmptyCity: Background Music", "m_factory": "Factory ambiance",
    "m_scavenger": "Lone Scavenger", "m_iron": "Iron wasteland", "m_fight": "Cyborg Factory Fight Theme", "m_boss": "Boss Battle #9 [Metal]",
}

MODELS = {
    "factory": ["machine", "machine-window", "machine-fortified", "machine-bed", "hopper-high-square",
                "hopper-round", "robot-arm-a", "robot-arm-b", "crane", "scanner-high", "scanner-low",
                "box-large", "box-wide", "box-small", "box-long", "cog-a", "screen-wide", "warning-traffic",
                "warning-orange", "pipe-large", "pipe-large-bend", "piston-round", "structure-yellow-short"],
    "td": ["weapon-turret", "weapon-cannon", "weapon-ballista", "tower-square-bottom-a", "tower-square-bottom-b",
           "tower-round-bottom-a", "tower-round-base", "tower-round-crystals", "tower-round-top-a",
           "detail-rocks", "detail-rocks-large", "detail-dirt", "detail-dirt-large"],
    "city": ["building-a", "building-c", "building-e", "building-f", "building-g", "building-l", "building-n",
             "building-p", "building-q", "building-r", "chimney-large", "chimney-medium", "chimney-small",
             "detail-tank", "detail-tank-large", "shipping-container-a", "shipping-container-b",
             "shipping-container-c", "solar-panel-landscape-group", "water-tower", "windmill-low"],
}

# Kenney's sci-fi frames are light grey with four tones (depth 116, outline 150,
# fill 218, highlight 255). Each style maps those tones to the game's palette:
# name -> (source, {tone: RGBA}).
# enemy type -> monster number in the 50+ Monsters Pack (static OBJ + palette).
ENEMIES = {"crawler": 53, "runner": 42, "brute": 43, "saboteur": 31, "glider": 14, "spitter": 12}

# item -> (pack, file, darken): painted item icons shown in the HUD.
ITEM_ICONS = {
    "iron_ore": ("scifi_items", "18.png", False), "coal": ("scifi_items", "16.png", True),
    "iron_plate": ("scifi_items", "1.png", False), "gear": ("scifi_items", "5.png", False),
    "ammo": ("apoc_icons", "18.png", False), "research_pack": ("scifi_items", "13.png", False),
    "military_pack": ("scifi_items", "4.png", False), "crystal": ("scifi_items", "17.png", False), "shell": ("scifi_items", "12.png", False),
}

UI_STYLES = {
    "panel": ("panel_glass_notches.png", {116: (8, 7, 6, 230), 150: (8, 7, 6, 235), 218: (14, 13, 11, 228), 255: (217, 128, 41, 170)}),
    "panel_info": ("panel_glass_notches.png", {116: (8, 7, 6, 230), 150: (8, 7, 6, 235), 218: (12, 15, 17, 232), 255: (89, 204, 255, 180)}),
    "panel_solid": ("panel_glass_notches.png", {116: (8, 7, 6, 250), 150: (8, 7, 6, 250), 218: (16, 15, 13, 248), 255: (217, 128, 41, 200)}),
    "button": ("button_square_depth.png", {116: (10, 9, 8, 255), 150: (16, 15, 13, 255), 218: (33, 30, 27, 245), 255: (84, 74, 62, 255)}),
    "button_hover": ("button_square_depth.png", {116: (10, 9, 8, 255), 150: (16, 15, 13, 255), 218: (56, 41, 26, 250), 255: (242, 153, 56, 255)}),
    "button_pressed": ("button_square.png", {116: (10, 9, 8, 255), 150: (16, 15, 13, 255), 218: (102, 61, 26, 250), 255: (255, 184, 92, 255)}),
    "button_disabled": ("button_square_depth.png", {116: (8, 8, 8, 200), 150: (12, 12, 12, 200), 218: (20, 20, 20, 200), 255: (46, 46, 46, 220)}),
    "bar_bg": ("button_square.png", {116: (8, 8, 8, 230), 150: (8, 8, 8, 230), 218: (24, 23, 21, 230), 255: (46, 42, 37, 240)}),
    "bar_fill": ("button_square.png", {116: (90, 50, 15, 255), 150: (90, 50, 15, 255), 218: (242, 153, 56, 255), 255: (255, 200, 120, 255)}),
}

ICONS = ["gear", "exitRight", "save", "import", "question", "trophy", "home", "pause", "right", "information",
         "musicOn", "audioOn", "wrench", "target", "warning", "power", "star", "locked", "checkmark",
         "cross", "fastForward", "return", "menuList", "zoom"]

# game event -> (pack, file stem)
SFX = {
    "gun": ("scifi_sfx", "impactMetal_002"),
    "gun2": ("scifi_sfx", "impactMetal_003"),
    "cannon": ("scifi_sfx", "lowFrequency_explosion_000"),
    "arc": ("scifi_sfx", "forceField_001"),
    "explosion": ("scifi_sfx", "explosionCrunch_000"),
    "explosion2": ("scifi_sfx", "explosionCrunch_002"),
    "wave": ("scifi_sfx", "computerNoise_001"),
    "transmission": ("scifi_sfx", "computerNoise_002"),
    "bite": ("scifi_sfx", "slime_000"),
    "die": ("scifi_sfx", "slime_001"),
    "build": ("ui_sfx", "drop_002"),
    "demolish": ("ui_sfx", "scratch_002"),
    "click": ("ui_sfx", "click_002"),
    "hover": ("ui_sfx", "tick_002"),
    "error": ("ui_sfx", "error_004"),
    "objective": ("ui_sfx", "confirmation_002"),
    "achievement": ("ui_sfx", "maximize_006"),
    "research": ("ui_sfx", "confirmation_004"),
}

MUSIC = {
    "menu": "m_menu",
    "calm_1": "m_empty",
    "calm_2": "m_factory",
    "calm_3": "m_scavenger",
    "calm_4": "m_iron",
    "combat": "m_fight",
    "boss": "m_boss",
}


def fetch(cache: Path, key: str) -> Path:
    _, name, _, _ = SOURCES[key]
    dest = cache / name.replace("%20", " ")
    if not dest.exists():
        print("baixando", OGA + name)
        req = urllib.request.Request(OGA + name, headers={"User-Agent": "last-industry-asset-import"})
        with urllib.request.urlopen(req) as r, open(dest, "wb") as f:
            shutil.copyfileobj(r, f)
    if dest.suffix != ".zip":
        return dest
    out = cache / ("x_" + dest.stem)
    if not out.exists():
        with zipfile.ZipFile(dest) as z:
            for m in z.namelist():
                # Refuse absolute paths and parent references from the archive.
                if m.startswith("/") or ".." in Path(m).parts:
                    raise SystemExit("caminho suspeito no zip: " + m)
            z.extractall(out)
    return out


def find(base: Path, pattern: str) -> Path:
    hits = sorted(base.rglob(pattern))
    if not hits:
        raise SystemExit("não encontrado: %s em %s" % (pattern, base))
    return hits[0]


def recolor(src: Path, dst: Path) -> None:
    """Pastel atlas -> worn industrial palette: blues/purples become steel and
    concrete, warm hues are kept (hazard paint, rust) but muted and darkened."""
    im = Image.open(src).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            deg = h * 360
            if 170 <= deg <= 330:          # blue, violet, pink -> warm grey steel
                s, v = s * 0.12, v * 0.72
                h = 30 / 360
            elif 80 <= deg < 170:           # greens -> oxidised olive
                h, s, v = 70 / 360, s * 0.45, v * 0.7
            else:                           # reds, oranges, yellows, beige
                s, v = s * 0.78, v * 0.82
            if s < 0.08:                    # near white/grey: dusty, never pure white
                v = min(v, 0.78)
                h, s = 30 / 360, max(s, 0.06)
            r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)


def grime(src: Path, dst: Path) -> None:
    """Monster palettes are bright; mute them so creatures fit the ash world
    (the game still tints them per type, elite and hit flash)."""
    im = Image.open(src).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            r2, g2, b2 = colorsys.hsv_to_rgb(h, s * 0.6, v * 0.8)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)


def restyle(src: Path, dst: Path, tones: dict) -> None:
    """Remaps the grey tones of a Kenney UI frame (piecewise by luminance)."""
    im = Image.open(src).convert("RGBA")
    px = im.load()
    keys = sorted(tones)
    for y in range(im.height):
        for x in range(im.width):
            r, _, _, a = px[x, y]
            if a == 0:
                continue
            v = min(max(r, keys[0]), keys[-1])
            i = max(k for k in range(len(keys)) if keys[k] <= v)
            j = min(i + 1, len(keys) - 1)
            t = 0.0 if i == j else (v - keys[i]) / (keys[j] - keys[i])
            c = [round(tones[keys[i]][n] * (1 - t) + tones[keys[j]][n] * t) for n in range(4)]
            c[3] = c[3] * a // 255
            px[x, y] = tuple(c)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)


def ffmpeg(src: Path, dst: Path, quality: int, loudness: float) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src),
                    "-af", "loudnorm=I=%s:TP=-1.5:LRA=11" % loudness,
                    "-ar", "44100", "-c:a", "libvorbis", "-q:a", str(quality), str(dst)], check=True)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=str(ROOT / ".asset_cache"))
    args = ap.parse_args()
    cache = Path(args.cache)
    cache.mkdir(parents=True, exist_ok=True)
    for sub in ["models", "ui", "icons/ui", "icons/items", "fonts", "sfx", "music"]:  # icons/buildings: render_icons.gd
        shutil.rmtree(OUT / sub, ignore_errors=True)

    for kit, names in MODELS.items():
        base = fetch(cache, kit)
        glb_dir = find(base, "GLB format")
        (OUT / "models" / kit).mkdir(parents=True, exist_ok=True)
        for n in names:
            shutil.copy(glb_dir / (n + ".glb"), OUT / "models" / kit / (n + ".glb"))
        recolor(glb_dir / "Textures" / "colormap.png", OUT / "models" / kit / "Textures" / "colormap.png")

    ui = fetch(cache, "ui")
    for name, (f, tones) in UI_STYLES.items():
        restyle(find(ui / "PNG" / "Extra" / "Default", f), OUT / "ui" / (name + ".png"), tones)
    (OUT / "fonts").mkdir(parents=True, exist_ok=True)
    for f in find(ui, "Font").glob("*.ttf"):
        shutil.copy(f, OUT / "fonts" / f.name)

    icons = fetch(cache, "icons")
    for n in ICONS:
        (OUT / "icons" / "ui").mkdir(parents=True, exist_ok=True)
        shutil.copy(find(icons / "PNG" / "White" / "2x", n + ".png"), OUT / "icons" / "ui" / (n + ".png"))

    for name, (pack, stem) in SFX.items():
        ffmpeg(find(fetch(cache, pack), stem + ".ogg"), OUT / "sfx" / (name + ".ogg"), 4, -16)
    for item, (pack, f, dark) in ITEM_ICONS.items():
        im = Image.open(find(fetch(cache, pack), f)).convert("RGBA")
        im.thumbnail((64, 64), Image.LANCZOS)
        if dark:  # white rock -> lump of coal
            px = im.load()
            for y in range(im.height):
                for x in range(im.width):
                    r, g, b, a = px[x, y]
                    v = (r + g + b) // 3
                    px[x, y] = (v * 30 // 100, v * 28 // 100, v * 26 // 100, a)
        (OUT / "icons" / "items").mkdir(parents=True, exist_ok=True)
        im.save(OUT / "icons" / "items" / (item + ".png"))
    monsters = fetch(cache, "monsters")
    for kind, n in ENEMIES.items():
        dst = OUT / "models" / "enemies"
        dst.mkdir(parents=True, exist_ok=True)
        shutil.copy(find(monsters, "Monster #%d.obj" % n), dst / (kind + ".obj"))
        grime(find(monsters / "50+ Monsters Pack 3D" / "UV Textures" / "Normal Colors", "Monster #%d Normal Color Palette.png" % n), dst / (kind + ".png"))
    for name, key in MUSIC.items():
        ffmpeg(fetch(cache, key), OUT / "music" / (name + ".ogg"), 2, -20)

    used = sorted(set(MODELS) | {"ui", "icons", "monsters"} | {p for p, _, _ in ITEM_ICONS.values()} | {p for p, _ in SFX.values()} | set(MUSIC.values()))
    manifest = {k: {"title": TITLES[k], "page": SOURCES[k][0], "file": SOURCES[k][1].replace("%20", " "), "author": SOURCES[k][2],
                    "license": SOURCES[k][3]} for k in used}
    (OUT / "sources.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n")
    print("ok:", OUT)


if __name__ == "__main__":
    sys.exit(main())
