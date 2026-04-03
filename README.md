# osu-winello_for_cn_fork


以下内容翻译自osu-winello原项目
# osu-winello
适用于 Linux 的 osu! stable 安装程序，包含打过补丁的 wine-osu 及其他功能。

![ezgif com-video-to-gif(1)](https://user-images.githubusercontent.com/98063377/224407211-70fa648c-b96f-442b-b5f5-eaf28a84670a.gif)

# 目录

- [安装](#安装)
	- [前置要求](#前置要求)
 		- [驱动](#驱动)		 
		- [PipeWire](#pipewire)
	- [安装 osu!](#安装-osu)
- [功能](#功能)
- [自定义](#自定义)
- [优化](#优化)
- [故障排除](#故障排除)
- [标志](#标志)
- [Steam Deck 支持](#steam-deck-支持)
- [致谢](#致谢)

# 安装

## 前置要求

除了 **64 位显卡驱动** 之外，唯一的依赖是 `git`、`zenity`、`wget`、`unzip` 和 `xdg-desktop-portal-gtk`（用于游戏内链接）。

你可以通过以下命令轻松安装它们：

**Ubuntu/Debian:** `sudo apt install -y git wget unzip zenity xdg-desktop-portal-gtk`

**Arch Linux:** `sudo pacman -Syu --needed  --noconfirm git wget unzip zenity xdg-desktop-portal-gtk`

**Fedora:** `sudo dnf install -y git wget unzip zenity xdg-desktop-portal-gtk`

**openSUSE:** `sudo zypper install -y git wget unzip zenity xdg-desktop-portal-gtk`

## 驱动：

虽然听起来很明显，但**正确**安装驱动是获得良好整体体验、避免性能低下或其他问题的必要条件。

请记住，osu! 需要 **64 位显卡驱动** 才能正常运行，因此如果你遇到性能问题，很可能与此有关。

对于 NVIDIA 来说，这通常是 `nvidia-utils` 或 `nvidia-driver`；对于 AMD/Intel 来说，通常是 `libgl1-mesa-dri`。

你可以在这里找到针对你发行版的更详细说明（只需要 64 位驱动）：
- [安装驱动](https://github.com/lutris/docs/blob/master/InstallingDrivers.md)

如果你仍然感到困惑，可以尝试通过你的包管理器安装 Steam。这将会为你安装发行版所需的驱动。

## PipeWire：

`PipeWire` **并不是真正的依赖，但强烈推荐，尤其是使用此脚本时。**

使用以下命令检查你的系统是否已安装：

```
LANG=C pactl info | grep "Server Name"
```

如果显示 `Server Name: PulseAudio (on Pipewire)`，那么你就可以继续了。

否则，请按照以下说明进行安装：
- [安装 PipeWire](https://github.com/NelloKudo/osu-winello/wiki/Installing-PipeWire)

## 安装 osu!：
```
git clone https://github.com/NelloKudo/osu-winello.git
cd osu-winello
chmod +x ./osu-winello.sh
./osu-winello.sh
```

现在你可以使用以下命令启动 osu!：
```
osu-wine
```
### ⚠ **!! \o/ !!** ⚠ :
- 你可能需要重新启动终端才能启动游戏。
- 使用 **-40/35ms** 的全局偏移来补偿 Wine 的 quirks（如果你使用音频兼容模式，则使用 -25ms）。这些数值对大多数设置有效，但可能会有所不同。请留意击打指示器！

# 功能：
- 附带**可更新的打过补丁的** [wine-osu](https://github.com/NelloKudo/WineBuilder/releases) 二进制文件，包含最新的 osu! 补丁，可实现低延迟音频、更好的性能、Alt-Tab 行为、崩溃修复等。
- 使用 [yawl](https://github.com/whrvt/yawl) 在 Steam 运行时中运行 wine-osu，无需下载依赖项即可在任何系统上提供出色的性能。
- 提供 [osu-handler](https://aur.archlinux.org/packages/osu-handler) 用于导入谱面和皮肤，通过 [rpc-bridge](https://github.com/EnderIce2/rpc-bridge) 支持 Discord RPC，并支持原生文件管理器！
- 支持最新的 [tosu](https://github.com/KotRikD/tosu) 和旧版 [gosumemory](https://github.com/l3lackShark/gosumemory)，用于数据流等，并可自动安装！（查看[标志](#标志)！）
- 将 osu! 安装到默认或自定义路径（使用 zenity 图形界面），也适用于 Windows 已有的 osu! 安装！
- 得益于[我的 osu-wineprefix 分支](https://gitlab.com/NelloKudo/osu-winello-prefix)，省去了下载 Wineprefix 的麻烦。
- 在 Wine 中预装 Windows 字体（日文字体、特殊字符等）的支持。

有关脚本所有功能的更清晰概述，DeepWiki 做了很好的总结。查看这里：
- [deepwiki/osu-winello](https://deepwiki.com/NelloKudo/osu-winello)

# 自定义

Winello 允许你使用位于以下位置的 `.cfg` 文件来设置启动参数或自定义环境变量：

```
~/.local/share/osuconfig/configs
```

提供了一个 `example.cfg` 文件，其中包含所有支持的环境变量以及使用说明。

### 示例
要将 `mangohud` 添加到启动参数，请编辑配置文件：

```sh
nano ~/.local/share/osuconfig/configs/example.cfg
# 或者直接使用：osu-wine --edit-config
```

在此处，取消注释现有的 `# PRE_LAUNCH_ARGS=""` 行（删除 #），或者添加一行新内容，如下所示：

```sh
PRE_LAUNCH_ARGS="mangohud"
```

如果你想始终在自定义服务器上运行，可以类似地编辑 `POST_LAUNCH_ARGS`。同一文件中显示了一个示例。

# 优化

由于发行版和设置的多样性，请按照以下指南优化你的 osu! 性能：
- [优化：osu! 性能](https://github.com/NelloKudo/osu-winello/wiki/Optimizing:-osu!-performance)

# 故障排除

请参阅 [osu-winello 的维基](https://github.com/NelloKudo/osu-winello/wiki) 进行各种类型的故障排除。

如果那没有帮助，可以：
- 加入 [ThePooN 的 Discord](https://discord.gg/bc4qaYjqyT) 并在 #osu-linux 频道中提问，他们会知道如何帮助你！<3
- 在 Discord 上给我写信 (marshnello)

# 标志：
**安装脚本：**
```
./osu-winello.sh: 安装游戏
./osu-winello.sh --no-deps: 安装游戏但跳过安装依赖
./osu-winello.sh uninstall: 卸载游戏
./osu-winello.sh fix-yawl: 尝试修复 yawl 问题（部分下载、损坏等）
```

**游戏脚本：**

```
osu-wine: 运行 osu!
osu-wine --help: 显示此帮助
osu-wine --info: 故障排除和更多信息
osu-wine --edit-config: 打开你的配置文件以编辑启动参数和其他自定义设置
osu-wine --winecfg : 在 osu! Wineprefix 上运行 winecfg
osu-wine --winetricks: 在 osu! Wineprefix 上安装软件包
osu-wine --regedit: 在 osu! Wineprefix 上打开注册表编辑器
osu-wine --wine <参数>: 就像在 osu 的 wineprefix 中使用普通 wine 一样，运行 wine 加上你的参数
osu-wine --kill: 终止 osu! 和 osu! Wineprefix 中的相关进程
osu-wine --kill9: 使用 wineserver -k9 终止 osu!
osu-wine --update: 将 wine-osu 更新到最新版本
osu-wine --fixprefix: 从系统重新安装 osu! Wineprefix
osu-wine --fixfolders: 重新配置 osu-handler 和原生文件集成（如果 osu!direct/.osz/.osk 处理，或者从游戏内打开文件夹/.osu/.osb 文件损坏，请运行此命令）
osu-wine --fix-yawl: 如果出现问题，重新安装与 yawl 和 Steam 运行时相关的文件
osu-wine --fixrpc: 如果需要，重新安装 rpc-bridge！
osu-wine --remove: 卸载 osu! 和脚本
osu-wine --changedir: 根据用户更改安装目录
osu-wine --devserver <地址>: 使用替代服务器运行 osu（例如 --devserver akatsuki.gg）
osu-wine --osuhandler <谱面, 皮肤..>: 使用指定的文件/链接启动 osu-handler-wine
osu-wine --gosumemory: 安装并运行 gosumemory，无需任何配置！
osu-wine --tosu: 安装并运行 tosu，无需任何配置！
osu-wine --disable-memory-reader: 关闭 gosumemory 和 tosu
osu-wine --akatsuki: 安装并运行 Akatsuki patcher
osu-wine --mappingtools: 安装并运行 osu! Mapping Tools（实验性，建议使用 WINE_USE_CACHY=true）
```

注意：任何命令都可以在开头加上字母 'n' 以避免在运行时更新。

例如 `osu-wine n --fixprefix` 将运行 `--fixprefix` 而不会覆盖来自 osu-winello git 仓库的任何文件

# Steam Deck 支持

由于 osu! 在 Steam Linux Runtime（与 Proton 相同）中的 Wine 上运行，你应该也可以在 Steam Deck 上玩！

建议不要在 Steam Deck 上手动安装 PipeWire，因为它默认已安装，尝试这样做可能会导致音频问题。

# 致谢

特别感谢：

- [whrvt aka spectator](https://github.com/whrvt/wine-osu-patches) 在 Wine、Proton 及相关方面的帮助，从未未能解决任何问题 :')
- [ThePooN 的 Discord](https://discord.gg/bc4qaYjqyT) 从早期阶段就支持 Winello！
- [gonX 的 wine-osu](https://drive.google.com/drive/folders/17MVlyXixv7uS3JW4B-H8oS4qgLn7eBw5)
- [Maot 集成的原生文件管理器](https://gist.github.com/maotovisk/1bf3a7c9054890f91b9234c3663c03a2)
- [KatouMegumi 的指南](https://wiki.archlinux.org/title/User:Katoumegumi#osu!_(stable)_on_Arch_Linux)
- [hwsnemo 的 wine-osu](https://software.opensuse.org//download.html?project=home%3Ahwsnemo%3Apackaged-wine-osu&package=wine-osu)
- [diamondburned 的 osu-wine](https://gitlab.com/osu-wine/osu-wine)
- [openglfreak 的软件包](https://github.com/openglfreak)
- [EnderIce2 的 rpc-bridge](https://github.com/EnderIce2/rpc-bridge)
- 最后但同样重要的是，每一位贡献者。感谢你们让 Winello 变得更好！

以上就是全部内容。祝玩 osu 愉快！

## 查看上面的指南以获取故障排除或额外工具！
