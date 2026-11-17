# SoundRing for Kindle Paperwhite 3

[简体中文](README.zh-CN.md) · [Changelog](CHANGELOG.md) · [Releases](../../releases)

SoundRing is an experimental Spotify Connect remote for a jailbroken Kindle Paperwhite 3. It displays playback on the e-ink screen and controls Spotify running on another device. **The Kindle does not stream or play audio.** This is an independent project, not affiliated with Spotify, Amazon, QQ Music or NetEase.

## Features

- Now playing: cover, track, artist, active device, Wi-Fi and battery; previous, play/pause, next, shuffle, repeat, refresh and library save. Short bars indicate whole minutes elapsed; they are indicators, not seek controls.
- Browse playlists and tracks with pagination and a back button, search Spotify with a QWERTY keyboard, and select a Spotify Connect device. Spotify may restrict particular playlists or endpoints depending on the application and account.
- Timed lyrics in two columns with automatic page changes and Chinese translations when a provider supplies a suitable translation. QQ Music is tried first, NetEase second; a local LRC file may be used as a fallback. Search results can also be selected manually. Neither match accuracy nor lyric/translation availability is guaranteed.
- Cache previously fetched lyrics, manual matches, artist aliases, information and images on the Kindle. Artist information is loaded progressively; data and images may be unavailable or inaccessible on a given network. Local cache contents are private to the device and are not included in the release.
- Displays the next item from the Spotify queue when accessible. A recovery shortcut and supervised session help restore the Kindle interface after an abnormal exit.

## Requirements

1. Kindle Paperwhite 3 (1072 × 1448), jailbroken, with working Wi-Fi and a compatible KUAL or Kindle Scriptlet launcher already installed. The current launcher explicitly accepts firmware Kindle 5.16.2.1.1 only; other firmware is refused at startup. Other models are not validated. Keep a separate recovery method and backup.
2. Spotify Premium, a Spotify developer app and a Spotify Connect device such as a phone. Spotify's [development-mode rules](https://developer.spotify.com/documentation/web-api/concepts/quota-modes) impose account, user and endpoint restrictions; functionality may vary. Playing controls require Premium. Start Spotify on the other device first.
3. A Windows computer with Python 3 and Tkinter for the included configuration tool, USB connection and browser. The configuration tool does not require a client secret.
4. Network access from the Kindle to Spotify and the chosen lyrics/artist services. Availability varies by location, DNS and network; access from mainland China is not guaranteed.

## Install

1. Download SoundRing KPW3 ZIP from Releases and extract it on your computer. The archive has `soundring/`, `extensions/`, `documents/` and `configuration-tool/` directories.
2. Connect the Kindle over USB and **back up any existing** `soundring/`, `extensions/soundring/` and SoundRing shortcuts. Keep existing `soundring/soundring-config.json`, `soundring/soundring-token.json`, `soundring/lyric-choices.json`, `soundring/artists/` and `soundring/lyrics-cache/` private and preserve them during upgrades. Do not replace your entire Kindle storage.
3. Merge the archive's `soundring/`, `extensions/`, and `documents/` into the Kindle USB root. Replace only corresponding SoundRing program files; do not delete existing personal data. The two documents shortcuts require a compatible Scriptlet launcher. KUAL users can also use the SoundRing menu; the recovery shortcut is a separate Scriptlet.
4. Keep `configuration-tool/` on the computer. Do not run the program while USB storage is mounted.

## Spotify authorization

1. Open the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) and create or reuse your own application. Enable Web API if prompted. Copy its **Client ID**; never publish a client secret or tokens.
2. Add a redirect URI in the dashboard. The default tool value is `http://127.0.0.1:8765/callback`; the value is editable and must match the dashboard entry. Spotify requires an explicit loopback IP rather than `localhost` ([redirect URI documentation](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri)). Add any other intended Spotify account to the app's development-mode allowlist as required.
3. On Windows, double-click `configuration-tool/启动配置工具.cmd` (or run `python config_gui.py`). Enter the Client ID and registered redirect URI, choose the lyrics source and polling interval, and start browser authorization. Sign in and accept the requested permissions; return to the tool after the callback completes.
4. Click **写入 Kindle 配置** and select the USB root containing `documents/`. The tool writes only `soundring/soundring-config.json` and `soundring/soundring-token.json` and backs up previous copies on the computer. These files contain credentials: never upload them or share diagnostic bundles without reviewing them.
5. Eject the Kindle safely, unplug USB, open Spotify on the playback device and begin playback. Launch **SoundRing Candidate** from the launcher or **启动 SoundRing** from KUAL. Use the top-right exit control when done and allow the Kindle interface to return.

## Using the application

- **Playback:** the app polls every 5 seconds by default (configurable 5–120 seconds). Changes can take longer due to network, Spotify limits or image loading. The minute bars illuminate as whole minutes pass; total duration appears beneath them.
- **Lyrics:** tap the lyrics icon; the view changes automatically as the track progresses. Tap the lyrics-selection area to choose QQ Music or NetEase, change the keyword, and select the correct candidate. An empty result or incorrect match can occur; translation depends on provider data. To provide a local file, place a timed UTF-8 LRC file at `soundring/lyrics/<Spotify-track-ID>.lrc`.
- **Artist and next track:** information loads in the background; use the paired arrows to switch between artists when present. The next-track label is informational. Missing images use the included fallback artwork.
- **Search:** digits appear above QWERTY letters. Left/right arrows move the caret; space, delete and search are below. Input is English or pinyin.
- **Cache maintenance:** the configuration tool can scan and, after your confirmation, remove validated automatic lyric cache files. Manual selections, corrupt files and unrecognized files are preserved. Automatic lyric and artist-portrait cache growth each has a 64 MiB budget; existing files are never automatically deleted and manual lyrics remain eligible for saving.
- **Repair lyric selections:** in the configuration tool, select the option to recover damaged lyric choices, choose the Kindle root, and confirm. It keeps a backup of the damaged index and restores only validated manual choices present in local lyric caches. Other choices cannot be reconstructed.
- **Recovery:** if the screen or stock interface fails to restore after exiting, disconnect USB and launch **SoundRing Recovery**, then wait for the Kindle interface to return. If it still fails, retain the logs and avoid repeatedly restarting. Recovery and long-running operation remain device-dependent; exercise caution.
- `soundring/package/session-limit` contains `0` for no timed exit; `180` or `600` sets a 3- or 10-minute trial. This setting does not guarantee fault-free continuous operation. Use USB storage to edit it only when SoundRing is not running.

## Troubleshooting and privacy

- **Cannot start:** verify jailbreak/launcher compatibility, authorization files, Wi-Fi, available storage and that another framebuffer app is not active. Inspect `soundring/logs/session.log` and `soundring/logs/soundring.log`; do not upload logs unreviewed.
- **Playback does not change:** start Spotify on a supported Connect device; check Premium and authorization, then use refresh. Some playlists, Spotify app configurations, API changes or network routes may be restricted. Playback has been exercised on one KPW3; behavior is not guaranteed for all accounts.
- **Missing lyrics, translations, artist name, biography or portrait:** results depend on metadata, matching, third-party services and network access. Manually select lyrics; try another keyword or a local LRC. Some artists have no accessible biography.
- **Rate limiting:** wait and retry instead of repeatedly tapping. Public Spotify and third-party services may change without notice.
- Do not publish token/config files, user playlists, local artist/lyrics caches, logs, account identifiers or personal paths. The release contains no preauthorized Spotify app or user-specific library data.

## Development and third-party material

`python tests/run_all.py` runs the portable tests with Python 3 and LuaJIT available. Some wire and launcher tests also need Bash and curl. On-device validation is separate.

The public repository excludes the MiSans font binary; for a local source build place the original unmodified `MiSans-Regular.ttf` in `assets/fonts/` after obtaining it under its license, then run `python tools/build_stage.py`. The distributable application ZIP includes MiSans as part of the application and its license. Kumbh Sans, Source Han Sans, Noto Sans and the optional Noto Sans KR fallback, and bundled runtime components have their respective license notices in `assets/fonts/`, `licenses/` and `runtime/`. This software uses the FreeType Project. FBInk is GPLv3+; see `runtime/THIRD_PARTY.md` and `runtime/FBInk-LICENSE` for sources and notices. Lyrics-provider adapters were informed by Lyricify Lyrics Helper; availability and third-party usage terms apply.

The project source is published without an additional open-source license grant at this time; third-party licenses remain applicable. Please do not assume that repository visibility alone grants redistribution rights.
