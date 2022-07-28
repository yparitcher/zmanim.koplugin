# zmanim.koplugin

## Features
- Supported on Kindle & Kobo
- Hebrew Calendar
- Daily zmanim
- Zmanim screensaver (Auto updates)
- Can last months on a charge

## Installation:

1. Install [KOReader](github.com/koreader/koreader)
2. Copy this folder to `koreader/plugins/`
3. Install [libzmanim](https://github.com/yparitcher/libzmanim) for your device from [LuaRocks](https://luarocks.org/modules/yparitcher/libzmanim/1.0-1) (Extract it to `koreader/rocks/`)

## Configuration 

All locations must contain:
1. Location name
2. Latitude (-90 - 90)
3. Longitude (-180 - 180)
4. Posix timezone string. For more details see the [Glibc manual](https://www.gnu.org/software/libc/manual/html_node/TZ-Variable.html)

![screenshot](/../screenshot/screenshot.png)
