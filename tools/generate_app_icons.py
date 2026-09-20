"""Regenerates the iOS icon assets from swift/Branding/AppIcon-source.jpeg (1024x1024).

Usage: python3 tools/generate_app_icons.py   (requires Pillow)
Writes the AppIcon, the launch-screen logo/background and SplashUI's in-app AppLogo.
"""
import json, os
from PIL import Image, ImageDraw
SWIFT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "swift")
SRC = f"{SWIFT}/Branding/AppIcon-source.jpeg"
APP = f"{SWIFT}/Splash/Resources/Assets.xcassets"
PKG = f"{SWIFT}/Packages/SplashKit/Sources/SplashUI/Resources/Media.xcassets"
src = Image.open(SRC).convert("RGB")

def dump(path, obj):
    with open(path, "w") as f: json.dump(obj, f, indent=2); f.write("\n")

def rounded(img, size, ratio=0.2237):
    # Supersampled mask so the baked corners match SwiftUI's rounded clip.
    ss = 4
    mask = Image.new("L", (size*ss, size*ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size*ss-1, size*ss-1), radius=int(size*ss*ratio), fill=255)
    out = img.resize((size, size), Image.LANCZOS).convert("RGBA")
    out.putalpha(mask.resize((size, size), Image.LANCZOS))
    return out

# App icon: single 1024 opaque PNG (iOS masks it).
d = f"{APP}/AppIcon.appiconset"
src.save(f"{d}/AppIcon.png")
dump(f"{d}/Contents.json", {"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
                             "info": {"author": "xcode", "version": 1}})

# Launch screen logo: 160pt rounded square, rendered at native size by UIKit.
d = f"{APP}/LaunchLogo.imageset"; os.makedirs(d, exist_ok=True)
imgs = []
for s in (1, 2, 3):
    name = f"LaunchLogo@{s}x.png" if s > 1 else "LaunchLogo.png"
    rounded(src, 160*s).save(f"{d}/{name}")
    imgs.append({"filename": name, "idiom": "universal", "scale": f"{s}x"})
dump(f"{d}/Contents.json", {"images": imgs, "info": {"author": "xcode", "version": 1}})

# Launch background: always black, matching SplashLoadingView.
d = f"{APP}/LaunchBackground.colorset"; os.makedirs(d, exist_ok=True)
black = {"color-space": "srgb", "components": {"red": "0.000", "green": "0.000", "blue": "0.000", "alpha": "1.000"}}
dump(f"{d}/Contents.json", {"colors": [{"idiom": "universal", "color": black}], "info": {"author": "xcode", "version": 1}})

# In-app logo (loader + About), clipped in SwiftUI.
os.makedirs(PKG, exist_ok=True)
dump(f"{PKG}/Contents.json", {"info": {"author": "xcode", "version": 1}})
d = f"{PKG}/AppLogo.imageset"; os.makedirs(d, exist_ok=True)
src.resize((512, 512), Image.LANCZOS).save(f"{d}/AppLogo.png", optimize=True)
dump(f"{d}/Contents.json", {"images": [{"filename": "AppLogo.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}})
