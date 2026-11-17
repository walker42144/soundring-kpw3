# Changelog

[简体中文](CHANGELOG.zh-CN.md)

## v0.1.1 — 2026-11-17

The second public release focuses on playback correctness, artist and lyric reliability, storage protection, and safer recovery.

### Playback and Spotify

- Clear stale title, progress, duration and playing state when Spotify reports no active playback. Treat a malformed or empty HTTP 200 playback response as an error instead of no playback.
- Stop repeatedly refreshing a revoked `invalid_grant` authorization; apply bounded backoff to transient refresh failures, keep legitimate Spotify `Retry-After` delays, and distinguish authorization, non-player permission and missing-content failures.
- Keep existing serial track selection and playback confirmation handling for playlists and search. Progress bars remain read-only by design.

### Lyrics, artist information and display

- Keep a manually chosen lyric selection when it is unavailable instead of silently switching to an automatic match. Protect selected and malformed lyric cache entries from automatic overwrite.
- Limit growth of automatic lyric caches and artist portrait caches to separate 64 MiB budgets. Existing cache files are never automatically deleted; manual lyric choices may still be saved above the automatic budget.
- Choose a larger available Spotify artist portrait; validate and normalize supported NetEase portrait URLs. Retry a cover once after local request-queue saturation, while rejecting stale results.
- Space MusicBrainz requests and identify the application; avoid disabling all artist biographies for 30 minutes after one unrelated failure.
- Add an optional Noto Sans KR fallback, a visible replacement for unsupported glyphs, faster long-title clipping and cached lyric pagination. Full complex-script shaping and bidirectional text remain unsupported.
- Show an inactive-device fallback and placeholders for unavailable list items; read fallback battery information asynchronously.

### Recovery, configuration and packaging

- Record session boot identity when available and avoid restoring stale framebuffer/process state from a different boot. Correct the order of recovery completion and lock release, and add a KUAL Recovery menu entry.
- Add configuration-tool actions to recover validated manual lyric choices from local cached entries after index damage, and to preview and explicitly clean validated automatic lyric caches. These actions preserve manual selections and do not run automatically.
- Require essential fonts when building, include the configuration tool, bilingual documentation and converter source in the staged bundle, and document the launcher firmware restriction. Source and release assets contain no preconfigured user credentials.

### Validation and limitations

- Portable host tests passed, including playback error handling, cache protection, configuration recovery/cleanup, artist throttling and simulated recovery ordering. Windows Git Bash emitted a `ulimit` warning; that host run does not establish the Kindle's file-size limit behavior.
- The user tested four incremental updates on one KPW3: normal startup, playback selection, lyrics, Korean display and normal exit were reported working; session logs show clean exit and requested Home restoration. This does not validate all devices, languages or networks. The config-tool maintenance actions were tested against temporary fixtures, not real user data; the KUAL Recovery menu has not been exercised on-device.
- A 72-hour virtual-time simulation with synthetic network delays and display timing passed. It is **not** a 72-hour real-device endurance test. Abrupt power loss, cross-boot recovery, sleep/wake and long-duration resource usage still need real-device testing. Chinese mainland network access and third-party lyric availability vary.
- The launcher currently only accepts Kindle firmware 5.16.2.1.1. Spotify development-mode and playlist access restrictions depend on the app and account.

## v0.1.0 — 2026-11-17

Initial public experimental release: Spotify Connect controls, playlists and search, lyrics, artist information, Windows configuration tool and recovery entry.
