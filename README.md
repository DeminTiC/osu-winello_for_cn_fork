# osu-winello_for_cn_fork
该项目由osu-winello项目衍生而来，为中国大陆地区设计，实现可选代理加速与全部内容汉化（包括起动器与注释）

对于本项目，您可以直接
```
git clone https://github.com/DeminTiC/osu-winello_for_cn_fork.git
cd osu-winello_for_cn_fork
chmod +x ./osu-winello.sh
./osu-winello.sh
```

除了正常运行的脚本，还有支持自定义镜像前缀、动态镜像列表，以及wget、DownloadFile函数调优


本人严格遵守GPL协议，配合原作者所有关于本项目的行为

如有问题请看wiki，置顶为Yawl的下载问题解释与解决方案

# 计划
1.将Yawl设置为可选项，不选择时安装lib32库
2.重新拾掇osu-winello-umu，重写Proton-osu脚本
3.重写Yawl（只是口嗨别当真，实际上我还不知道怎么重写）

以下内容翻译自osu-winello原项目

# osu-winello

适用于 Linux 的 osu! stable 安装程序，包含打过补丁的 wine-osu 及其他功能。

![ezgif com-video-to-gif(1)](https://user-images.githubusercontent.com/98063377/224407211-70fa648c-b96f-442b-b5f5-eaf28a84670a.gif)

# 目录

- [安装](#安装)
	- [前置条件](#前置条件)
 		- [显卡驱动](#显卡驱动)		 
		- [PipeWire](#pipewire)
	- [安装 osu!](#安装-osu)
- [功能特性](#功能特性)
- [自定义配置](#自定义配置)
- [优化](#优化)
- [故障排除](#故障排除)
- [命令行参数](#命令行参数)
- [Steam Deck 支持](#steam-deck-支持)
- [致谢](#致谢)

# 安装

## 前置条件

除了 **64 位显卡驱动** 之外，唯一需要的软件包是 `git`、`zenity`、`wget`、`unzip` 和 `xdg-desktop-portal-gtk`（用于游戏内链接）。

你可以通过以下命令轻松安装它们：

**Ubuntu/Debian:** `sudo apt install -y git wget unzip zenity xdg-desktop-portal-gtk`

**Arch Linux:** `sudo pacman -Syu --needed --noconfirm git wget unzip zenity xdg-desktop-portal-gtk`

**Fedora:** `sudo dnf install -y git wget unzip zenity xdg-desktop-portal-gtk`

**openSUSE:** `sudo zypper install -y git wget unzip zenity xdg-desktop-portal-gtk`

## 显卡驱动：

虽然听起来显而易见，但**正确**安装驱动对于获得良好的整体体验、避免性能不佳或其他问题至关重要。

请记住，osu! 需要 **64 位显卡驱动** 才能正常运行，因此如果你遇到性能问题，很可能与此相关。

对于 NVIDIA 显卡，通常需要安装类似 `nvidia-utils` 或 `nvidia-driver` 的软件包；对于 AMD/Intel 显卡，通常需要 `libgl1-mesa-dri`。

你可以在此处找到针对你的发行版的更详细说明（只需 64 位驱动即可）：
- [安装显卡驱动](https://github.com/lutris/docs/blob/master/InstallingDrivers.md)

如果你仍不清楚如何操作，可以尝试通过包管理器安装 Steam，这会为你的发行版安装必要的驱动。

## PipeWire：

`PipeWire` **并非必需依赖，但强烈推荐安装，尤其是配合本脚本使用时。**

使用以下命令检查你的系统是否已安装 PipeWire：

```
LANG=C pactl info | grep "Server Name"
```

如果输出 `Server Name: PulseAudio (on Pipewire)`，则说明已就绪。

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
### ⚠ **!! \o/ !!** ⚠ ：
- 你可能需要重新启动终端才能启动游戏。
- 使用 **-40/35ms** 的全局偏移量来弥补 Wine 的 quirks（如果你使用了音频兼容模式，则使用 -25ms）。这些数值适用于大多数配置，但根据你的实际情况可能有所不同。请留意击打误差计！

# 功能特性：
- 附带**可更新的、打过补丁的** [wine-osu](https://github.com/NelloKudo/WineBuilder/releases) 二进制文件，包含最新的 osu! 补丁，可实现低延迟音频、更高性能、Alt+Tab 行为优化、崩溃修复等。
- 使用 [yawl](https://github.com/whrvt/yawl) 在 Steam 运行时中运行 wine-osu，无需下载依赖即可在各种系统上提供出色的性能。
- 提供 [osu-handler](https://aur.archlinux.org/packages/osu-handler) 用于导入谱面和皮肤，通过 [rpc-bridge](https://github.com/EnderIce2/rpc-bridge) 支持 Discord Rich Presence，并支持原生文件管理器！
- 支持最新的 [tosu](https://github.com/KotRikD/tosu) 和旧版 [gosumemory](https://github.com/l3lackShark/gosumemory)，用于直播等场景，并可自动安装！（请参阅[命令行参数](#命令行参数)！）
- 将 osu! 安装到默认或自定义路径（使用 zenity 图形界面），同时支持从 Windows 已有的 osu! 安装直接使用！
- 得益于 [我的 fork](https://gitlab.com/NelloKudo/osu-winello-prefix) 版本的 [osu-wineprefix](https://gitlab.com/osu-wine/osu-wineprefix)，免去了手动下载 Wineprefix 的麻烦。
- 支持 Wine 中预装的 Windows 字体（日文字体、特殊字符等）。

关于脚本所做一切的更清晰概述，DeepWiki 做了很好的总结。请查看：
- [deepwiki/osu-winello](https://deepwiki.com/NelloKudo/osu-winello)

# 自定义配置

Winello 允许你使用位于以下目录中的 `.cfg` 文件来设置启动参数或自定义环境变量：

```
~/.local/share/osuconfig/configs
```

提供了一个 `example.cfg` 文件，其中包含所有支持的环境变量以及使用说明。

### 示例  
要添加 `mangohud` 到启动参数，请编辑配置文件：

```sh
nano ~/.local/share/osuconfig/configs/example.cfg
# 或直接使用：osu-wine --edit-config
```

在文件中，取消注释现有的 `# PRE_LAUNCH_ARGS=""` 行（删除 # 号），或者新增一行，如下所示：

```sh
PRE_LAUNCH_ARGS="mangohud"
```

如果你希望始终在自定义服务器上运行，只需类似地编辑 `POST_LAUNCH_ARGS` 即可。同一个文件中提供了示例。

# 优化

由于发行版和配置的多样性，请按照以下指南来优化你的 osu! 性能：
- [优化：osu! 性能](https://github.com/NelloKudo/osu-winello/wiki/Optimizing:-osu!-performance) 

# 故障排除

有关任何类型的故障排除，请参考 [osu-winello 的 wiki](https://github.com/NelloKudo/osu-winello/wiki)。

如果这没有帮助，你可以：
- 加入 [ThePooN 的 Discord](https://discord.gg/bc4qaYjqyT) 并在 #osu-linux 频道提问，他们会知道如何帮助你！<3
- 在 Discord 上给我发消息 (marshnello)

# 命令行参数：
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
osu-wine --help: 显示本帮助
osu-wine --info: 故障排除和更多信息
osu-wine --edit-config: 打开配置文件以编辑启动参数和其他自定义设置
osu-wine --winecfg : 在 osu! 的 Wineprefix 上运行 winecfg
osu-wine --winetricks: 在 osu! 的 Wineprefix 上安装软件包
osu-wine --regedit: 在 osu! 的 Wineprefix 上打开注册表编辑器
osu-wine --wine <args>: 在 osu! 的 Wineprefix 内运行 wine 及你的参数，就像使用普通 wine 一样
osu-wine --kill: 终止 osu! 及其在 osu! Wineprefix 中的相关进程
osu-wine --kill9: 使用 wineserver -k9 终止 osu!
osu-wine --update: 将 wine-osu 更新到最新版本
osu-wine --fixprefix: 从系统重新安装 osu! Wineprefix（添加 --redl 可重新下载预构建的 prefix，而不是重新创建）
osu-wine --fixfolders: 重新配置 osu-handler 和原生文件集成（如果 osu!direct/.osz/.osk 文件处理，或从游戏内打开文件夹/.osu/.osb 文件出现问题，请运行此命令）
osu-wine --fix-yawl: 如果出现问题，重新安装与 yawl 和 Steam Runtime 相关的文件
osu-wine --fixrpc: 如果需要，重新安装 rpc-bridge！
osu-wine --remove: 卸载 osu! 和本脚本
osu-wine --changedir: 根据用户更改安装目录
osu-wine --devserver <地址>: 使用备用服务器运行 osu（例如 --devserver akatsuki.gg）
osu-wine --osuhandler <谱面, 皮肤..>: 使用指定的文件/链接启动 osu-handler-wine
osu-wine --gosumemory: 安装并运行 gosumemory，无需任何配置！
osu-wine --tosu: 安装并运行 tosu，无需任何配置！
osu-wine --disable-memory-reader: 关闭 gosumemory 和 tosu
osu-wine --akatsuki: 安装并运行 Akatsuki 补丁程序
osu-wine --mappingtools: 安装并运行 osu! Mapping Tools（实验性功能，建议设置 WINE_USE_CACHY=true）
```

注意：任何命令都可以在前面加上字母 'n' 来避免在运行时进行更新。

例如：`osu-wine n --fixprefix` 将运行 `--fixprefix`，但不会覆盖来自 osu-winello git 仓库的任何文件。

# Steam Deck 支持

由于 osu! 通过 Wine 在 Steam Linux Runtime（与 Proton 相同）中运行，你应该也可以在 Steam Deck 上畅玩！

建议不要在 Steam Deck 上手动安装 PipeWire，因为它已经默认安装，尝试手动安装可能导致音频问题。

# 致谢

特别感谢：

- [whrvt aka spectator](https://github.com/whrvt/wine-osu-patches) 在 Wine、Proton 及相关方面的帮助，从未让人失望 :')
- [ThePooN 的 Discord](https://discord.gg/bc4qaYjqyT) 从 Winello 早期阶段就给予支持！
- [gonX 的 wine-osu](https://drive.google.com/drive/folders/17MVlyXixv7uS3JW4B-H8oS4qgLn7eBw5)
- [Maot 的原生文件管理器集成方案](https://gist.github.com/maotovisk/1bf3a7c9054890f91b9234c3663c03a2)
- [KatouMegumi 的指南](https://wiki.archlinux.org/title/User:Katoumegumi#osu!_(stable)_on_Arch_Linux)
- [hwsnemo 的 wine-osu](https://software.opensuse.org//download.html?project=home%3Ahwsnemo%3Apackaged-wine-osu&package=wine-osu)
- [diamondburned 的 osu-wine](https://gitlab.com/osu-wine/osu-wine)
- [openglfreak 的软件包](https://github.com/openglfreak)
- [EnderIce2 的 rpc-bridge](https://github.com/EnderIce2/rpc-bridge)
- 最后但同样重要的是，每一位贡献者。感谢你们让 Winello 变得更好！

以上就是全部内容。祝玩 osu! 愉快！

## 如需故障排除或使用额外工具，请查看上面的指南！
