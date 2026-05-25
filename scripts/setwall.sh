#!/usr/bin/env bash
# setwall —— 切换壁纸 + 重跑 matugen 染色,niri 上的 swww/awww 通用
# 用法:
#   setwall <image-path>          切到指定图,fade 过渡
#   setwall <image-path> wipe     指定过渡类型(fade/wipe/grow/center/wave/...)
#   setwall random                从 ~/Pictures/Wallpaper 随机抽一张

set -euo pipefail

WALL_DIR="${WALL_DIR:-$HOME/Pictures/Wallpaper}"
TRANSITION="${2:-fade}"

if [[ "${1:-}" == "random" ]]; then
    img="$(find "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n 1)"
elif [[ -f "${1:-}" ]]; then
    img="$1"
else
    echo "usage: $(basename "$0") <image|random> [transition]" >&2
    exit 2
fi

# 1. 切壁纸
awww img "$img" \
    --transition-type "$TRANSITION" \
    --transition-duration 0.8 \
    --transition-fps 60

# 2. 重跑 matugen,所有模板自动重新生成(GTK / fuzzel / qs colors.json / ...)
# --source-color-index 0:选最显著色,跳过 matugen 4.x 的交互菜单
matugen image "$img" --source-color-index 0

# 3. 由 matugen 的 colors.json 派生终端 OSC 颜色序列,直接广播到所有活终端
#    新开 zsh 由 .zshrc 自己读 colors.json,这里只管活终端的实时刷新
#    Material You → ANSI 16 的映射跟 .zshrc 里那段保持一致
COLORS_JSON="$HOME/.local/state/quickshell/user/generated/colors.json"
if [[ -f "$COLORS_JSON" ]] && command -v jq >/dev/null; then
    mapfile -t C < <(jq -r '
        .background, .on_background, .primary,
        (.surface_container_lowest // .background),
        .error, .tertiary, .secondary, .primary,
        .tertiary_container, .primary_container, .on_surface,
        (.surface_container_low // .surface),
        .error_container,
        (.on_tertiary_container // .tertiary),
        (.on_secondary_container // .secondary),
        (.on_primary_container // .primary),
        (.tertiary_fixed // .tertiary),
        (.primary_fixed // .primary),
        (.inverse_surface // .on_background)
    ' "$COLORS_JSON")
    # C[0]=bg C[1]=fg C[2]=cursor C[3..18]=ANSI 0..15
    ESC=$'\033'; ST=$'\033\\'
    OSC=""
    for i in {0..15}; do OSC+="${ESC}]4;${i};${C[$((i+3))]}${ST}"; done
    OSC+="${ESC}]10;${C[1]}${ST}${ESC}]11;${C[0]}${ST}${ESC}]12;${C[2]}${ST}"

    for pts in /dev/pts/[0-9]*; do
        [[ -w "$pts" ]] && printf '%s' "$OSC" > "$pts" 2>/dev/null || true
    done
fi

echo "wallpaper set: $img"
