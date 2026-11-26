# Omarchy Dotfiles & Post-Install Setup

Personal dotfiles and resilient post-install debloat/optimization script for **Omarchy** (Arch Linux + Hyprland), tuned for older hardware and C++ competitive programming.

> **Neovim CP IDE:** My Neovim configuration lives separately at [RustamSheoran/nvim](https://github.com/RustamSheoran/nvim).

---

## Quick Start (Fresh Omarchy Install)

```bash
git clone https://github.com/RustamSheoran/dotfiles.git ~/github/dotfiles
cd ~/github/dotfiles
bash setup-omarchy.sh
```

Optionally, install my Neovim config alongside it:

```bash
git clone https://github.com/RustamSheoran/nvim.git ~/.config/nvim
bash ~/.config/nvim/setup.sh
```

*(You can safely re-run `setup-omarchy.sh` anytime — it skips anything that doesn't exist, continues past non-fatal errors, and prints a summary of any real failures at the end.)*

---

## What `setup-omarchy.sh` Does

1. **Removes unused packages** (only if installed):
   - `signal-desktop`, `typora`, `serein-bin`
   - `docker`, `docker-compose`, `docker-buildx`, `ufw-docker`, `lazydocker`
   - `system-config-printer`
   - `fcitx5-mozc`, `fcitx5-chinese-addons`, `fcitx5-chewing`, `fcitx5-hangul` *(keeps `omarchy-fcitx5` for Compose key)*
2. **Installs essentials** (if missing):
   - `foot`, `rmpc`, `mpd`, `mpd-mpris`, `pacman-contrib` (`paccache`), `mold`, `clang`, `gcc`, and `zen-browser-bin` (via `yay`)
3. **Disables background bloat & enables SSD TRIM:**
   - Disables user services: `bt-agent`, `voxtype`, `mpd`, `mpd-mpris` (started on-demand via `Super + M`), `owed`, and masks/hides `localsearch-3`
   - Disables `omarchy toggle crash-capture`
   - Disables system services: `bluetooth`, `avahi-daemon`, `docker.socket` *(keeps `warp-svc`)*
   - Enables weekly SSD TRIM (`fstrim.timer`)
4. **Disk, Log & I/O Optimizations:**
   - **Pacman auto-clean hook** (`/etc/pacman.d/hooks/paccache.hook`): clears `.pkg.tar.zst` cache after every transaction (`paccache -rk0; paccache -ruk0`)
   - **Journald cap** (`/etc/systemd/journald.conf.d/size.conf`): limits logs to `100M`
   - **BFQ I/O scheduler** (`/etc/udev/rules.d/60-ioscheduler.rules`): keeps the desktop responsive during large file transfers
5. **Deploys Dotfiles:**
   - `.config/hypr/{bindings,looknfeel,input}.lua` (fast animations, `0.92/0.87` terminal opacity, hardware `kb_options = ""`, on-demand `mpd` + `rmpc` in `foot`, restored Tmux/Calculator/Spotify/YouTube bindings)
   - `.config/omarchy/shell.json` (trimmed bar layout)
   - `.config/foot/foot.ini` (`Ctrl+Shift+C/V` + `Ctrl/Shift+Insert` copy/paste)
   - `.bashrc` & `.clang-format`

---

## Terminal & Shell Shortcuts

### Hidden Gems (`bash` + `fzf` + `zoxide`)
- **`Ctrl + R`**: Fuzzy-search your command history (`Enter` to run, `Right Arrow`/`Tab` to edit first)
- **`Ctrl + T`**: Fuzzy-find a file and paste its path into your current command
- **`Alt + C`**: Fuzzy-find a subfolder and `cd` into it
- **`Alt + .`** *(Alt + dot)*: Insert the **last argument** of your previous command
- **`sudo !!`**: Re-run your last command with `sudo`
- **`cd -`**: Jump back to your previous directory
- **`Ctrl + A` / `Ctrl + E`**: Jump to start / end of the line
- **`Ctrl + W`**: Delete word before cursor
- **`Ctrl + U` / `Ctrl + K`**: Cut everything before / after cursor
- **`Ctrl + L`**: Clear screen without losing what you typed
- **`zi`**: Interactive `fzf` menu of your most-visited folders

### Custom Aliases & Functions (`.bashrc`)
- **`cpr <file.cpp>`**: Compile with `g++ -O2 -std=c++17 -fuse-ld=mold` (hits `c++17_O2.gch` in ~0.27s) and run immediately
- **`cpsan <file.cpp>`**: Compile with `-D_GLIBCXX_ASSERTIONS -fsanitize=address,undefined -g` and run
- **`gph <msg>`**: `git add . && git commit -m "<msg>" && git push`
- **`cf`**: `cd ~/cp && nvim`
- **`gtn`**: `cd ~/.config/nvim`

### Hyprland Keybinds
- **`Super + K`**: Searchable keybindings cheatsheet
- **`Super + M`**: Start `mpd` on-demand and open/focus `rmpc` in `foot`
- **`Super + Alt + Enter`**: Tmux
- **`Super + C` / `Super + V`**: Universal copy/paste (works in `foot` too)
