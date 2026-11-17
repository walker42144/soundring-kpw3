# SoundRing for Kindle Paperwhite 3

[English](README.md) · [更新记录](CHANGELOG.zh-CN.md) · [下载 Releases](../../releases)

SoundRing 是为已越狱 Kindle Paperwhite 3 制作的实验性 Spotify Connect 遥控器：墨水屏显示播放信息，音乐由手机、音箱或其他 Spotify 设备播放，**Kindle 本身不播放音频**。本项目与 Spotify、Amazon、QQ 音乐和网易云音乐均无隶属关系。

## 功能

- 播放页：封面、歌名、艺人、播放设备、Wi-Fi 和电量；上一首、播放／暂停、下一首、随机、循环、刷新、收藏。短条按已播完的整分钟点亮，仅用于显示，不能拖动或点击跳进度。
- 歌单和歌曲分页、返回，Spotify 搜索和设备选择。Spotify 对不同开发者应用、账号及歌单的接口权限可能不同。
- 双栏同步歌词，随播放时间自动换页；来源提供且能匹配时显示中文翻译。默认先尝试 QQ 音乐，再尝试网易云，亦支持本地 LRC；可以手动搜索和选择正确结果。不能保证每首歌曲都匹配成功或有翻译。
- 歌词、手动选择、艺人别名、资料和图片会保存在设备本地。多艺人资料逐步加载；图片和介绍取决于来源及网络，缺失图片时使用默认头像。发行包不包含个人缓存。
- 在接口可用时显示下一首；提供独立恢复入口及受监控的运行机制，协助异常退出后恢复 Kindle 界面。

## 准备工作

1. Kindle Paperwhite 3（1072 × 1448），已越狱、Wi-Fi 可用，并已安装兼容的 KUAL 或 Kindle Scriptlet 启动器。当前启动器明确只接受 Kindle 5.16.2.1.1 固件，其他固件会在启动前拒绝；其他型号尚未验证。请保留独立恢复方式并备份。
2. Spotify Premium、自己的 Spotify 开发者应用，以及手机或音箱等 Spotify Connect 播放设备。[Spotify 开发模式规则](https://developer.spotify.com/documentation/web-api/concepts/quota-modes)对账号、用户数和接口有额外限制；播放控制需要 Premium。先在播放设备启动 Spotify。
3. 配置工具需要 Windows、Python 3（含 Tkinter）、浏览器和 USB。无需输入 Client Secret。
4. Kindle 能访问 Spotify 和所选歌词／艺人资料服务。中国大陆的网络、DNS 和服务可用性各不相同，不能保证所有服务可连接。

## 安装

1. 从 Releases 下载并解压 SoundRing KPW3 ZIP。压缩包含 `soundring/`、`extensions/`、`documents/` 和 `configuration-tool/`。
2. 通过 USB 连接 Kindle。先备份已有 `soundring/`、`extensions/soundring/` 和 SoundRing 快捷方式。升级时特别保留 `soundring/soundring-config.json`、`soundring/soundring-token.json`、`soundring/lyric-choices.json`、`soundring/artists/` 和 `soundring/lyrics-cache/`；这些可能包含个人信息。不要覆盖或删除整个 Kindle 存储。
3. 将压缩包中 `soundring/`、`extensions/`、`documents/` 合并复制到 Kindle USB 根目录，只替换对应的 SoundRing 程序文件，保留个人数据。documents 中的两个快捷方式需要兼容 Scriptlet 的启动器；KUAL 也提供 SoundRing 菜单。恢复快捷方式是独立 Scriptlet。
4. `configuration-tool/` 保存在电脑上。Kindle 处于 USB 存储模式时不要运行应用。

## Spotify 授权

1. 打开 [Spotify 开发者控制台](https://developer.spotify.com/dashboard)，创建或使用已有应用；提示时启用 Web API，复制 **Client ID**。不要公开 Client Secret 或令牌。
2. 在开发者控制台添加回调地址。工具默认 `http://127.0.0.1:8765/callback`，也可修改；工具中的地址应与控制台配置一致。Spotify 要求使用明确的本机回环 IP，而不是 `localhost`（[官方说明](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri)）。如其他 Spotify 账号需要访问，按开发模式要求加入允许名单。
3. 在 Windows 双击 `configuration-tool/启动配置工具.cmd`，或运行 `python config_gui.py`。填写 Client ID 和回调地址，选择歌词来源及刷新间隔，发起浏览器授权。登录并同意权限，完成回调后返回工具。
4. 点击**写入 Kindle 配置**，选择包含 `documents/` 的 Kindle USB 根目录。工具只写入 `soundring/soundring-config.json` 和 `soundring/soundring-token.json`，旧配置会先备份到电脑。它们包含授权信息，切勿上传或分享。
5. 安全弹出并拔下 Kindle；在手机等设备打开 Spotify 并开始播放。通过启动器打开 **SoundRing Candidate**，或从 KUAL 选择**启动 SoundRing**。退出时点击右上角退出，等待 Kindle 界面恢复。

## 操作说明

- **播放页**：默认每 5 秒查询播放状态，可在配置工具中设为 5–120 秒。网络、接口限流和封面加载可能使实际同步更慢。分钟短条随整分钟点亮，下面显示歌曲总时长。
- **歌词**：点击歌词图标进入歌词视图，按播放时间自动切换。点击歌词选择区域可切换 QQ 音乐或网易云、更改关键词并手动选择结果。翻译依赖服务提供；匹配不到时可尝试其他关键词。也可将 UTF-8 带时间标记的 LRC 放在 `soundring/lyrics/<Spotify歌曲ID>.lrc`。
- **艺人与下一首**：资料在后台依次加载；多位艺人可用并排箭头切换。下一首名称仅供显示。无图片时显示默认头像。
- **搜索**：最上方数字，其下是 QWERTY 字母，左右箭头移动光标，底部为空格、删除和搜索。目前输入英文或拼音。
- **专辑封面**：Spotify 专辑封面转换后保存在 `soundring/cover-cache/`，再次播放时优先复用。封面图片上限为 256 MiB，空间不足时优先淘汰最久未使用的封面；缓存不可用时仍可正常下载显示。缓存可能反映听歌记录，请勿公开。
- **缓存维护**：配置工具可扫描自动歌词缓存，并在你确认后清理可验证的条目；手动选择、损坏或无法验证的文件会保留。自动歌词和艺人头像缓存各有 64 MiB 增长预算，不会自动删除已有文件，手动歌词仍可保存。
- **恢复歌词选择**：在配置工具中选择从缓存恢复损坏的歌词选择，选择 Kindle 根目录并确认。工具会备份损坏的索引，只恢复本地缓存中可验证的手动选择；其他选择需要重新选择。
- **恢复**：退出后若屏幕或系统界面未恢复，请拔掉 USB，打开 **SoundRing Recovery**，等待系统界面恢复。如果仍失败，保留日志，不要反复重启。恢复机制和长时间运行仍取决于设备环境。
- `soundring/package/session-limit` 为 `0` 时不按时间自动退出；填 `180` 或 `600` 分别为 3 或 10 分钟测试模式。无限运行并不保证不会发生故障，仅在应用未运行时通过 USB 修改。

## 常见问题与隐私

- **打不开**：检查越狱与启动器兼容性、授权文件、Wi-Fi、存储空间以及是否有其他程序占用屏幕。可查看 `soundring/logs/session.log` 与 `soundring/logs/soundring.log`；分享前先检查并删除个人信息。
- **不能切歌**：先在其他支持 Connect 的设备播放，检查 Premium、授权和网络，再点击刷新。部分歌单、开发者应用、接口变动或网络可能受限。本项目已在一台 KPW3 上进行过操作验证，不代表适用于所有账号与设备。
- **缺少歌词、翻译、中文名、介绍或头像**：受歌曲元数据、匹配结果、第三方服务及网络影响。可以手动选择歌词、换关键词或使用本地 LRC；部分艺人没有可获取的介绍。
- **请求频繁／限流**：等待后重试，不要持续点击。第三方接口可能变更或停止服务。
- 请勿公开配置、令牌、个人歌单、艺人／歌词缓存、日志、账户标识及本地路径。发行包不包含作者的 Spotify 授权或用户音乐库。

## 开发和第三方组件

安装 Python 3 与 LuaJIT 后运行 `python tests/run_all.py`；部分网络和启动脚本测试还需要 Bash 与 curl。电脑端测试不能替代实机测试。

公开源码仓库不单独分发 MiSans 字体文件；从官方获取并遵守其许可后，将原始未修改的 `MiSans-Regular.ttf` 放入 `assets/fonts/`，再运行 `python tools/build_stage.py` 构建。发行版应用包内包含 MiSans 及其许可文件。Kumbh Sans、思源黑体、Noto Sans、可选韩文回退字体 Noto Sans KR 及运行时组件的许可见 `assets/fonts/`、`licenses/`、`runtime/`。本软件使用 FreeType；FBInk 为 GPLv3+，相关源码及许可见 `runtime/THIRD_PARTY.md` 和 `runtime/FBInk-LICENSE`。歌词接入参考 Lyricify Lyrics Helper，使用时须遵守第三方服务条款。

项目源码目前未额外指定开源许可证；第三方许可证仍适用。仓库公开不自动代表授权再分发。
