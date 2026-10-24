#!/usr/bin/env bash
# The AppImage of the Linux package: one file that carries the launcher, the engine and its data
# files, with a desktop entry and icon, for any x86-64 distribution with glibc 2.38, a Vulkan
# driver, Python 3 and FUSE 2 (libfuse.so.2, as every AppImage needs).
#
#   packaging/linux/appimage.sh <package folder> <version> [appimagetool]
#
# The package folder is what packaging/linux/build.sh wrote (engine/out/package/<name>); the
# AppImage goes beside it as <name>-v<version>-x86_64.AppImage. appimagetool is the argument, else
# the one on PATH, else APPIMAGETOOL.
#
# An AppImage is read-only, and the engine writes beside itself: its prepared files (engine/out),
# the settings (lantern.ini), saves and the shader cache (user/), mods, logs. AppRun points all of
# that to a data folder, ~/.local/share/paleblood-engine (PALEBLOOD_DATA_DIR), through the
# variables bb-start, run.sh and the launcher already honour (BB_DATA_DIR, BB_OUT_DIR, BB_CONFIG,
# BB_GPU_USER_DIR), and links the engine's programs into the data folder's engine/out, where the
# start scripts look for them beside the prepared files (fresh links each start: the AppImage
# mounts at a new place every time).
set -euo pipefail
package=$(cd -- "${1:?usage: packaging/linux/appimage.sh <package folder> <version> [appimagetool]}" && pwd)
version=${2:?usage: packaging/linux/appimage.sh <package folder> <version> [appimagetool]}
tool=${3:-${APPIMAGETOOL:-$(command -v appimagetool || true)}}
[[ -n $tool && -x $tool ]] || { echo 'appimagetool is needed: https://github.com/AppImage/appimagetool/releases (appimagetool-x86_64.AppImage), as the third argument or on PATH' >&2; exit 1; }
here=$(cd -- "$(dirname -- "$0")" && pwd)
name=$(basename -- "$package")      # PalebloodEngine
id=paleblood-engine                 # the desktop entry, icon and data folder
title="Paleblood Engine"
out=$(dirname -- "$package")
appdir=$out/$name.AppDir
rm -rf "$appdir"
mkdir -p "$appdir/usr/share/icons/hicolor/256x256/apps" "$appdir/usr/share/applications"
cp -r "$package" "$appdir/$name"

install -m755 "$here/AppRun" "$appdir/AppRun"
sed -i "s|@NAME@|$name|g; s|@ID@|$id|g" "$appdir/AppRun"

cat > "$appdir/$id.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$title
GenericName=Bloodborne on PC
Comment=Runs your own copy of Bloodborne; a changed version of Lantern Engine by Awaken
Exec=AppRun
Icon=$id
Terminal=false
Categories=Game;
Keywords=Bloodborne;PS4;Lantern;
X-AppImage-Version=$version
DESKTOP
cp "$appdir/$id.desktop" "$appdir/usr/share/applications/"
# The icon: the launcher's own, rendered from its .ico at 256 px (packaging/linux/icon.png).
install -m644 "$here/icon.png" "$appdir/$id.png"
install -m644 "$here/icon.png" "$appdir/usr/share/icons/hicolor/256x256/apps/$id.png"
ln -sf "$id.png" "$appdir/.DirIcon"

appimage=$out/$name-v$version-x86_64.AppImage
rm -f "$appimage"
# appimagetool itself is an AppImage: extract-and-run needs no FUSE on the build machine.
ARCH=x86_64 "$tool" --appimage-extract-and-run --no-appstream "$appdir" "$appimage" > "$out/appimagetool.log" 2>&1 || {
    tail -20 "$out/appimagetool.log" >&2
    echo "appimagetool failed (log: $out/appimagetool.log)" >&2
    exit 1
}
rm -rf "$appdir"
echo "AppImage: $appimage ($(du -h "$appimage" | cut -f1))"
