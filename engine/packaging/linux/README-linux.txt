Paleblood Engine for Linux (x86-64)

Paleblood Engine is a changed version of Lantern Engine by Awaken (github.com/Awakenchan/LanternEngine),
not an official Lantern Engine release: it adds the US edition CUSA00900, one shared shader cache for
every 1.09 edition, and this Linux package and AppImage built from source. Source and releases:
github.com/djanice1980/LanternEngine. The launcher is Lantern Engine's, renamed with the fork.

AppImage: put it where it will stay (~/Applications), make it executable (chmod +x
Paleblood*.AppImage) and run it; it needs FUSE 2 (libfuse.so.2) like every AppImage. Its first start
adds it to the applications menu (an entry and icon for the file where it is, kept up to date
when the file moves); --uninstall removes them, PALEBLOOD_NO_MENU=1 leaves the menu alone. Settings, saves, mods, logs and the shader cache go to
~/.local/share/paleblood-engine (or $PALEBLOOD_DATA_DIR). From a terminal:
    ./Paleblood-Engine-*.AppImage --play /path/to/CUSA00900
--play on its own starts the game through the launcher with its saved game folder and settings,
without showing it (what Play > Add to Steam sets up). The tar.gz package below keeps everything
in its own folder instead.

Steam Deck: works from the AppImage. Keep Engine > "New memory and translation model" off (the
launcher's recommended settings and its default do that on a Deck: on, the engine stops at the
start). Output 1280 x 800 (the Deck's own screen; the HUD stays 16:9 in the middle, the world
fills the screen), FSR 4 with FSR 3.1 frame generation and 90 FPS on a Deck OLED play well; the
launcher's recommended settings choose them. Play it from the Steam shortcut the launcher's "Add to
Steam" makes (Steam closed while it is added): it also sets the shortcut's controller layout to
Steam's Gamepad template. Without that, Game Mode gives a non-Steam shortcut a keyboard-and-mouse
layout, the left stick types W/A/S/D and the hunter moves as with a d-pad. A shortcut made another
way: on the game's page press the controller icon, Current Layout, Templates, Gamepad, Apply Layout.

Needs: a Vulkan 1.3 GPU driver (Mesa RADV for AMD, NVIDIA's own driver, Intel ANV), glibc 2.39 or
later (Ubuntu 24.04, Debian 13, Fedora 40, Arch, SteamOS 3.6, Bazzite), Python 3, X11 or Wayland.
Any x86-64 CPU: the programs are built for plain x86-64 in an Ubuntu 24.04 container
(packaging/linux/release-docker.sh), so a Steam Deck's Zen 2 runs them.

Start: open "Paleblood Engine" (the launcher, the same as on Windows): pick the game folder (the
one with eboot.bin and sce_module), then Play. If your file manager does not run it, run
    chmod +x "Paleblood Engine" lantern.sh engine/out/bb-start
once in this folder.

From a terminal instead:
    ./lantern.sh /path/to/CUSA03173   (or CUSA00900: the US edition with update 1.09 runs the same code)
The folder is remembered, so later starts need only ./lantern.sh. A CUSA03173 folder next to
this one, or inside it, is found without the argument.

Shaders: the first start after an update recompiles the shader cache, and the shipped shader
catalog is added to it once, so most pipelines are built before the game starts (a GPU from
another vendor than the catalog's still builds its own as it plays).

Wayland: the game runs natively. If the window closes at the start with "Wayland display
connection closed by server" in the log, the compositor ended the connection: a driver and
compositor mismatch (NVIDIA 615 drivers on KDE Plasma did; 580 ran clean). Another driver
version, or SDL_VIDEODRIVER=x11 before ./lantern.sh (XWayland), avoids it. KDE Plasma 6.8.1
flickers on some hybrid NVIDIA laptops; 6.8.0 does not.

Settings: the launcher, lantern.ini in this folder, or the in-game menu (Insert, or L3+R3 on a
controller). Saves go to user/, mods to mods/, and each session's log to logs/ (attach the newest
one to a bug report).

Updates: the launcher updates itself and the engine from the releases page (Settings > Updates),
keeping lantern.ini, user/, mods/ and logs/.

Frame generation: lsfg-vk (lsfg-vk.dev, with Lossless Scaling from Steam) works as a Vulkan layer.
Engine page > Graphics > "Frame generation: lsfg-vk" picks the multiplier: the launcher keeps a
"Paleblood Engine" profile for bb-probe in ~/.config/lsfg-vk/conf.toml, caps the game at the
screen's refresh rate over the multiplier, and the log's "Frame generation:" line says whether the
layer was found.

DLSS: NVIDIA's DLSS runtime is in engine/out (libnvidia-ngx-dlss.so.*); it needs an RTX GPU and
NVIDIA's own driver (libnvidia-ngx.so.1). DLSS Frame Generation is Windows only.

Not on Linux yet: FSR 4 through AMD's Windows DLL and the native PC option pages; the in-game menu
covers the settings.
