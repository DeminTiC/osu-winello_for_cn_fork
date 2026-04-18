#!/usr/bin/env bash

#   =======================================
#   欢迎使用 Winello！
#   整个脚本被划分为不同的函数以方便阅读。
#   欢迎贡献代码！
#   =======================================

# 当前 Wine-osu 版本（用于更新）
MAJOR=10
MINOR=15
PATCH=8
WINEVERSION=$MAJOR.$MINOR-$PATCH
LASTWINEVERSION=0

# Wine-osu 镜像地址
WINELINK="https://github.com/NelloKudo/WineBuilder/releases/download/wine-osu-staging-${WINEVERSION}/wine-osu-winello-fonts-wow64-${WINEVERSION}-x86_64.tar.xz"
WINECACHYLINK="https://github.com/NelloKudo/WineBuilder/releases/download/wine-osu-cachyos-v10.0-3/wine-osu-cachy-winello-fonts-wow64-10.0-3-x86_64.tar.xz"

# 其他外部下载的版本
DISCRPCBRIDGEVERSION=1.2
GOSUMEMORYVERSION=1.3.9
TOSUVERSION=4.3.1
YAWLVERSION=0.8.2
MAPPINGTOOLSVERSION=1.12.27

# 其他下载链接
WINETRICKSLINK="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"                 # 用于 --fixprefix 的 Winetricks
PREFIXLINK="https://github.com/NelloKudo/osu-winello/releases/download/winello-bins/osu-winello-prefix.tar.xz" # 默认 WINEPREFIX
OSUMIMELINK="https://github.com/NelloKudo/osu-winello/releases/download/winello-bins/osu-mime.tar.gz"          # osu-mime（文件关联）
YAWLLINK="https://github.com/whrvt/yawl/releases/download/v${YAWLVERSION}/yawl"                                # yawl（用于 Steam Runtime 的 Wine 启动器）

OSUDOWNLOADURL="https://m1.ppy.sh/r/osu!install.exe"

DISCRPCLINK="https://github.com/EnderIce2/rpc-bridge/releases/download/v${DISCRPCBRIDGEVERSION}/bridge.zip"
GOSUMEMORYLINK="https://github.com/l3lackShark/gosumemory/releases/download/${GOSUMEMORYVERSION}/gosumemory_windows_amd64.zip"
TOSULINK="https://github.com/tosuapp/tosu/releases/download/v${TOSUVERSION}/tosu-windows-v${TOSUVERSION}.zip"
AKATSUKILINK="https://air_conditioning.akatsuki.gg/loader"
MAPPINGTOOLSLINK="https://github.com/OliBomby/Mapping_Tools/releases/download/v${MAPPINGTOOLSVERSION}/mapping_tools_installer_x64.exe"

# 本 Git 仓库的 URL
WINELLOGIT="https://github.com/DeminTiC/osu-winello_for_cn_fork.git"

# 根据用户选择返回镜像URL
get_mirror_url() {
    local url="$1"
    if [ "${USE_CDN:-0}" = "1" ] && [[ "$url" == *"github.com"* ]]; then
        # 换用 dpik 镜像，cdnghproxy速度过慢
        echo "https://github.dpik.top/$url"
    else
        echo "$url"
    fi
}

# osu-winello.sh 所在的目录
SCRDIR="$(realpath "$(dirname "$0")")"
# osu-winello.sh 的完整路径
SCRPATH="$(realpath "$0")"

# 导出的全局变量

export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export BINDIR="${BINDIR:-$HOME/.local/bin}"

OSUPATH="${OSUPATH:-}" # 可能由 osu-wine 启动器、osuconfig/osupath 导出，或者在首次安装时为空（将在 installOrChangeDir 中设置）

# 不要依赖这个！我们应该从 `osu-wine --update` 获取启动器路径，这是一个支持从 umu 更新的“hack”
if [ -z "${LAUNCHERPATH}" ]; then
    LAUNCHERPATH="$(realpath /proc/$PPID/exe)" || LAUNCHERPATH="$(readlink /proc/$PPID/exe)"
    [[ ! "${LAUNCHERPATH}" =~ .*osu.* ]] && LAUNCHERPATH=
fi
[ -z "${LAUNCHERPATH}" ] && LAUNCHERPATH="$BINDIR/osu-wine" # 如果仍然找不到，就使用默认目录

export WINEDLLOVERRIDES="winemenubuilder.exe=;" # 阻止 Wine 创建 .desktop 文件
export WINEDEBUG="-wineboot,${WINEDEBUG:-}"     # 不显示“failed to start winemenubuilder”

export WINENTSYNC="${WINENTSYNC:-0}" # 为了安全，在安装相关操作中不使用这些
export WINEFSYNC="${WINEFSYNC:-0}"   # （仍然不要覆盖启动器设置，因为如果 wineserver 使用不同设置运行，将无法启动）
export WINEESYNC="${WINEESYNC:-0}"

# 其他 shell 局部变量
WINETRICKS="${WINETRICKS:-"$XDG_DATA_HOME/osuconfig/winetricks"}"
YAWL_INSTALL_PATH="${YAWL_INSTALL_PATH:-"$XDG_DATA_HOME/osuconfig/yawl"}"
export WINE="${WINE:-"${YAWL_INSTALL_PATH}-winello"}"
export WINESERVER="${WINESERVER:-"${WINE}server"}"
export WINEPREFIX="${WINEPREFIX:-"$XDG_DATA_HOME/wineprefixes/osu-wineprefix"}"
export WINE_INSTALL_PATH="${WINE_INSTALL_PATH:-"$XDG_DATA_HOME/osuconfig/wine-osu"}"

# 使所有路径对 pressure-vessel 可见
[ -z "${PRESSURE_VESSEL_FILESYSTEMS_RW}" ] && {
    _mountline="$(df -P "$SCRPATH" 2>/dev/null | tail -1)" && [ -n "${_mountline}" ] && _mainscript_mount="${_mountline##* }:"  # 主脚本路径的挂载点
    _mountline="$(df -P "$LAUNCHERPATH" 2>/dev/null | tail -1)" && [ -n "${_mountline}" ] && _curdir_mount="${_mountline##* }:" # 当前目录的挂载点
    _mountline="$(df -P "$XDG_DATA_HOME" 2>/dev/null | tail -1)" && [ -n "${_mountline}" ] && _home_mount="${_mountline##* }:"  # XDG_DATA_HOME 的挂载点
    PRESSURE_VESSEL_FILESYSTEMS_RW+="${_mainscript_mount:-}${_curdir_mount:-}${_home_mount:-}/mnt:/media:/run/media"
    [ -r "$XDG_DATA_HOME/osuconfig/osupath" ] && OSUPATH=$(</"$XDG_DATA_HOME/osuconfig/osupath") &&
        PRESSURE_VESSEL_FILESYSTEMS_RW+=":$(realpath "$OSUPATH"):$(realpath "$OSUPATH"/Songs 2>/dev/null)" # osu/songs 目录的挂载点
    export PRESSURE_VESSEL_FILESYSTEMS_RW="${PRESSURE_VESSEL_FILESYSTEMS_RW//\/:/:}"                       # 清理任何单独的“/”挂载，pressure-vessel 不喜欢那样
}

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

#   =====================================
#   =====================================
#           安装器函数
#   =====================================
#   =====================================

# 简单的 echo 函数（但带有酷炫的文字 e.e）
Info() {
    echo -e '\033[1;34m'"Winello:\033[0m $*"
}

Warning() {
    echo -e '\033[0;33m'"Winello (警告):\033[0m $*"
}

# 退出安装但在某些情况下不回滚的函数
Quit() {
    echo -e '\033[1;31m'"Winello:\033[0m $*"
    exit 1
}

# 在任何类型失败时回滚安装的函数
Revert() {
    echo -e '\033[1;31m'"正在回滚安装...:\033[0m"
    rm -f "$XDG_DATA_HOME/icons/osu-wine.png"
    rm -f "$XDG_DATA_HOME/applications/osu-wine.desktop"
    rm -f "$BINDIR/osu-wine"
    rm -rf "$XDG_DATA_HOME/osuconfig"
    rm -f "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz"
    rm -f "/tmp/osu-mime.tar.xz"
    rm -rf "/tmp/osu-mime"
    rm -f "$XDG_DATA_HOME/mime/packages/osuwinello-file-extensions.xml"
    rm -f "$XDG_DATA_HOME/applications/osuwinello-file-extensions-handler.desktop"
    rm -f "$XDG_DATA_HOME/applications/osuwinello-url-handler.desktop"
    rm -f "/tmp/winestreamproxy-2.0.3-amd64.tar.xz"
    rm -rf "/tmp/winestreamproxy"
    echo -e '\033[1;31m'"回滚完成，请再次运行 ./osu-winello.sh\033[0m"
    exit 1
}

# 指向 Revert() 的错误函数，并带有适当的信息
InstallError() {
    echo -e '\033[1;31m'"脚本失败:\033[0m $*"
    Revert
}

# 用于除安装之外的其他功能的错误函数
Error() {
    echo -e '\033[1;31m'"脚本失败:\033[0m $*"
    return 0 # 不要退出，自行处理错误，如果需要则向启动器传递结果
}

# 大量函数成功的简写
okay="eval Info 完成！ && return 0"

wgetcommand="wget -q --show-progress"
_wget() {
    local url="$1"
    local output="$2"
    $wgetcommand "$url" -O "$output" && return 0
    { [ $? = 2 ] && wgetcommand="wget"; } || wgetcommand="wget --no-check-certificate"
    $wgetcommand "$url" -O "$output" && return 0
    wgetcommand='' # 损坏，从今以后使用 curl
    return 1
}

DownloadFile() {
    local original_url="$1"
    local output="$2"
    local url
    url=$(get_mirror_url "$original_url")
    Info "下载 $original_url 到 $output (实际地址: $url)..."
    if [ -n "$wgetcommand" ] && command -v wget >/dev/null 2>&1; then
        _wget "$url" "$output" && return 0
    fi
    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$url" -o "$output" && return 0
    fi
    Error "下载 $original_url 失败，请检查网络连接。"
    return 1
}

# 通过遍历进程树来检测当前运行的 shell
detectRunningShell() {
    local current_shell=""
    local ppid=$PPID
    local max_iterations=10
    local iteration=0
    
    while [ "$ppid" -gt 1 ] && [ $iteration -lt $max_iterations ]; do
        iteration=$((iteration + 1))
        
        if [ -f "/proc/$ppid/status" ]; then
            ppid=$(grep "^PPid:" /proc/$ppid/status | awk '{print $2}')
            
            if [ -f "/proc/$ppid/comm" ]; then
                local proc_name=$(cat /proc/$ppid/comm)
                
                case "$proc_name" in
                    bash|zsh|fish|ksh|mksh|dash|tcsh|csh) # 我希望这些已经足够...
                        current_shell="$proc_name"
                        break
                        ;;
                esac
            fi
        else
            break
        fi
    done
    
    # 如果检测失败，回退到 $SHELL
    if [ -z "$current_shell" ]; then
        current_shell=$(basename "$SHELL")
    fi
    
    echo "$current_shell"
}

# 查找安装所需基本内容的函数
InitialSetup() {
    # 最好不要以 root 身份运行脚本，对吧？
    if [ "$USER" = "root" ]; then InstallError "请不要使用 root 运行脚本"; fi

    # 检查旧版本的 osu-wine（我的或 DiamondBurned 的）
    if [ -e /usr/bin/osu-wine ]; then Quit "请在安装之前卸载旧版 osu-wine (/usr/bin/osu-wine)！"; fi
    if [ -e "$BINDIR/osu-wine" ]; then Quit "请在安装之前卸载 Winello (osu-wine --remove)！"; fi

    Info "欢迎使用本脚本！按照指引安装 osu! 8)"

    # 询问下载镜像选择
    Info "选择下载源："
    Info "1) GitHub 直连 (默认，部分地区可能较慢)"
    Info "2) CDN 镜像 (使用 dpik 站加速 GitHub 资源)"
    read -r -p "$(Info "请输入选择 [1/2]: ")" mirror_choice
    if [ "$mirror_choice" = "2" ]; then
        export USE_CDN=1
        Info "已启用 CDN 镜像 (GitHub 资源将通过 https://github.dpik.top/* 下载)。"
    else
        export USE_CDN=0
    fi

    # 检查 $BINDIR 是否在 PATH 中：
    mkdir -p "$BINDIR"
    pathcheck=$(echo "$PATH" | grep -q "$BINDIR" && echo "y")

    # 如果 $BINDIR 不在 PATH 中：
    if [ "$pathcheck" != "y" ]; then
        current_shell=$(detectRunningShell)
        
        case "$current_shell" in
            bash)
                touch -a "$HOME/.bashrc"
                echo "export PATH=$BINDIR:\$PATH" >>"$HOME/.bashrc"
                Info "已将 $BINDIR 添加到 ~/.bashrc 的 PATH 中（请重启 shell 或运行：source ~/.bashrc）"
                ;;
            zsh)
                touch -a "$HOME/.zshrc"
                echo "export PATH=$BINDIR:\$PATH" >>"$HOME/.zshrc"
                Info "已将 $BINDIR 添加到 ~/.zshrc 的 PATH 中（请重启 shell 或运行：source ~/.zshrc）"
                ;;
            fish)
                mkdir -p "$HOME/.config/fish" && touch -a "$HOME/.config/fish/config.fish"
                fish -c "fish_add_path $BINDIR/"
                Info "已将 $BINDIR 添加到 fish 配置的 PATH 中（请重启 shell）"
                ;;
            *)
                Warning "无法检测到 shell ($current_shell)。请手动将 $BINDIR 添加到你的 PATH 中"
                ;;
        esac
    fi

    # 嗯，我们确实需要互联网吧...
    Info "正在检查网络连接.."
    ! ping -c 2 114.114.114.114 >/dev/null 2>&1 && ! ping -c 2 www.bing.com >/dev/null 2>&1 && InstallError "请先连接互联网再继续 xd。请重新运行脚本"

    # 查找依赖项..
    deps=(pgrep realpath wget zenity unzip)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            InstallError "请在继续之前安装 $dep！"
        fi
    done
}

# 辅助函数，等待 wineserver 关闭后再继续下一步，减少不稳定性的机会
# 不要返回失败，这很可能是无害的、无关的或作为成功指标不可靠（除了特定情况）
waitWine() {
    {
        "$WINESERVER" -w
        "$WINE" "${@:-"--version"}"
    }
    return 0
}

# 安装脚本文件、yawl 和 Wine-osu 的函数
InstallWine() {
    # 安装游戏启动器及相关内容...
    Info "正在安装游戏脚本："
    cp "${SCRDIR}/osu-wine" "$BINDIR/osu-wine" && chmod +x "$BINDIR/osu-wine"

    Info "正在安装图标："
    mkdir -p "$XDG_DATA_HOME/icons"
    cp "${SCRDIR}/stuff/osu-wine.png" "$XDG_DATA_HOME/icons/osu-wine.png" && chmod 644 "$XDG_DATA_HOME/icons/osu-wine.png"

    Info "正在安装 .desktop："
    mkdir -p "$XDG_DATA_HOME/applications"
    echo "[Desktop Entry]
Name=osu!
Comment=osu! - 节奏只需轻轻一点！
Type=Application
Exec=$BINDIR/osu-wine %U
Icon=$XDG_DATA_HOME/icons/osu-wine.png
Terminal=false
Categories=Wine;Game;" | tee "$XDG_DATA_HOME/applications/osu-wine.desktop" >/dev/null
    chmod +x "$XDG_DATA_HOME/applications/osu-wine.desktop"

    if [ -d "$XDG_DATA_HOME/osuconfig" ]; then
        Info "跳过 osuconfig.."
    else
        mkdir "$XDG_DATA_HOME/osuconfig"
    fi

    Info "正在安装 Wine-osu："
    # 下载 Wine..
    DownloadFile "$WINELINK" "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz" || InstallError "无法下载 wine-osu。"

    # 这将解压 Wine-osu 并将最后版本设置为下载的版本
    tar -xf "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz" -C "$XDG_DATA_HOME/osuconfig"
    LASTWINEVERSION="$WINEVERSION"
    rm -f "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz"

    # 尽快安装并验证 yawl，包装器模式如果没有传递参数则不会下载/安装运行时
    installYawl || Revert

    # 更新函数在此文件夹下工作：它将 osuconfig 中文件存储的变量与 GitHub 上的最新值进行比较，并检查是否需要更新
    Info "正在安装用于更新的脚本副本.."
    mkdir -p "$XDG_DATA_HOME/osuconfig/update"

    { git clone . "$XDG_DATA_HOME/osuconfig/update" || git clone "${WINELLOGIT}" "$XDG_DATA_HOME/osuconfig/update"; } ||
        InstallError "Git 失败，请检查你的网络连接.."

    git -C "$XDG_DATA_HOME/osuconfig/update" remote set-url origin "${WINELLOGIT}"

    echo "$LASTWINEVERSION" >>"$XDG_DATA_HOME/osuconfig/wineverupdate"
}

# 配置游戏安装文件夹的函数
InitialOsuInstall() {
    local installpath=1
    Info "你想在哪里安装游戏？：
          1 - 默认路径 ($XDG_DATA_HOME/osu-wine)
          2 - 自定义路径"
    read -r -p "$(Info "请选择你的选项：")" installpath

    case "$installpath" in
    '2')
        installOrChangeDir || return 1
        ;;
    *)
        Info "安装到默认路径.. ($XDG_DATA_HOME/osu-wine)"
        installOrChangeDir "$XDG_DATA_HOME/osu-wine" || return 1
        ;;
    esac
    $okay
}

# 真正的 Winello 来了 8)
# 脚本将按顺序安装：
# - osu!mime 和 osu!handler 以正确导入皮肤和谱面
# - Wine 前缀
# - 注册表键值以将原生文件管理器与 Wine 集成
# - rpc-bridge 用于 Discord RPC（flatpak 用户请搜索“flatpak discord rpc”）
FullInstall() {
    # 是时候安装我预先打包的 Wine 前缀了，这在大多数情况下都有效
    # 脚本仍然捆绑了 osu-wine --fixprefix，这应该也能为我完成工作

    mkdir -p "$XDG_DATA_HOME/osuconfig/configs" # 创建 configs 目录，如果不存在则复制示例配置
    [ ! -r "$XDG_DATA_HOME/osuconfig/configs/example.cfg" ] && cp "${SCRDIR}/stuff/example.cfg" "$XDG_DATA_HOME/osuconfig/configs/example.cfg"

    Info "正在配置 Wine 前缀："

    # 检查下载是否完成的变量
    local failprefix="false"
    mkdir -p "$XDG_DATA_HOME/wineprefixes"
    if [ -r "$XDG_DATA_HOME/wineprefixes/osu-wineprefix/system.reg" ]; then
        Info "Wine 前缀已存在；你想重新安装它吗？"
        Warning "除非你知道自己在做什么，否则强烈建议重新安装！"
        read -r -p "$(Info "请选择 (y/N)：")" prefchoice
        if [ "$prefchoice" = 'y' ] || [ "$prefchoice" = 'Y' ]; then
            rm -rf "$XDG_DATA_HOME/wineprefixes/osu-wineprefix"
        fi
    fi

    # 如果没有前缀（或用户想要重新安装）：
    if [ ! -r "$XDG_DATA_HOME/wineprefixes/osu-wineprefix/system.reg" ]; then
        # 下载前缀到临时 ~/.winellotmp 文件夹
        # 以解决此问题：https://github.com/NelloKudo/osu-winello/issues/36
        mkdir -p "$HOME/.winellotmp"
        DownloadFile "${PREFIXLINK}" "$HOME/.winellotmp/osu-winello-prefix.tar.xz" || Revert

        # 检查是手动创建前缀还是从仓库安装
        if [ "$failprefix" = "true" ]; then
            reconfigurePrefix nowinepath fresh || Revert
        else
            tar -xf "$HOME/.winellotmp/osu-winello-prefix.tar.xz" -C "$XDG_DATA_HOME/wineprefixes"
            mv "$XDG_DATA_HOME/wineprefixes/osu-prefix" "$XDG_DATA_HOME/wineprefixes/osu-wineprefix"
            reconfigurePrefix nowinepath || Revert
        fi
        # 清理..
        rm -rf "$HOME/.winellotmp"
    fi

    # 现在设置桌面文件等，无论前缀是新的还是旧的
    osuHandlerSetup || Revert

    Info "配置并安装 osu!"
    InitialOsuInstall || Revert

    Info "安装完成！运行 'osu-wine' 开始玩 osu!"
    Warning "如果 'osu-wine' 不起作用，只需关闭并重新打开你的终端。"
    exit 0
}

#   =====================================
#   =====================================
#          安装后函数
#   =====================================
#   =====================================

longPathsFix() {
    Info "正在应用长歌曲名称修复（例如因为 osu! 文件夹嵌套过深）..."

    # 将默认的 wine 前缀用户名替换为当前用户的用户名
    sed -i -e "s|nellokudo|${USER}|g" "${WINEPREFIX}"/{userdef.reg,user.reg,system.reg}

    rm -rf "$WINEPREFIX/dosdevices"
    rm -rf "$WINEPREFIX/drive_c/users/nellokudo"
    mkdir -p "$WINEPREFIX/dosdevices"
    ln -s "$WINEPREFIX/drive_c/" "$WINEPREFIX/dosdevices/c:"
    ln -s / "$WINEPREFIX/dosdevices/z:"
    ln -s "$OSUPATH" "$WINEPREFIX/dosdevices/d:" 2>/dev/null # 全新安装时失败也没关系
    waitWine wineboot -u
    return 0
}

saveOsuWinepath() {
    local osupath="${OSUPATH}"
    if [ -z "${osupath}" ]; then
        { [ -r "$XDG_DATA_HOME/osuconfig/osupath" ] && osupath=$(<"$XDG_DATA_HOME/osuconfig/osupath"); } || {
            Error "找不到 osu! 的路径！" && return 1
        }
    fi

    Info "正在保存 osu! 路径的副本..."

    PRESSURE_VESSEL_FILESYSTEMS_RW="$(realpath "$osupath"):$(realpath "$osupath"/Songs 2>/dev/null):${PRESSURE_VESSEL_FILESYSTEMS_RW}"
    export PRESSURE_VESSEL_FILESYSTEMS_RW

    local temp_winepath
    temp_winepath="$(waitWine winepath -w "$osupath")"
    [ -z "${temp_winepath}" ] && Error "无法从 winepath 获取 osu! 路径... 请检查 $osupath/osu!.exe ？" && return 1

    echo -n "${temp_winepath}" >"$XDG_DATA_HOME/osuconfig/.osu-path-winepath"
    echo -n "${temp_winepath}osu!.exe" >"$XDG_DATA_HOME/osuconfig/.osu-exe-winepath"
    $okay
}

deleteFolder() {
    local folder="${1}"
    Info "是否要删除 ${folder} 中的先前安装？"
    read -r -p "$(Info "请选择你的选项 (y/N)：")" dirchoice

    if [ "$dirchoice" = 'y' ] || [ "$dirchoice" = 'Y' ]; then
        read -r -p "$(Info "你确定吗？这将删除你的 osu! 文件！(y/N)")" dirchoice2
        if [ "$dirchoice2" = 'y' ] || [ "$dirchoice2" = 'Y' ]; then
            rm -rf "${folder}" || { Error "无法删除文件夹！" && return 1; }
            return 0
        fi
    fi
    Info "跳过.."
    return 0
}

# 处理 `osu-wine --changedir` 和安装设置
installOrChangeDir() {
    local newdir="${1:-}"
    local lastdir="${OSUPATH:-}"
    if [ -z "${newdir}" ]; then
        Info "请选择你的 osu! 目录："
        newdir="$(zenity --file-selection --directory)"
        [ ! -d "$newdir" ] && { Error "未选择文件夹，请确保已安装 zenity.." && return 1; }
    fi

    [ ! -s "$newdir/osu!.exe" ] && newdir="$newdir/osu!" # 除非 osu!.exe 已存在，否则创建子目录
    if [ -s "$newdir/osu!.exe" ] || [ "$newdir" = "$lastdir" ]; then
        Info "osu! 安装已存在..."
    else
        mkdir -p "$newdir"
        DownloadFile "${OSUDOWNLOADURL}" "$newdir/osu!.exe" || return 1

        [ -n "${lastdir}" ] && { deleteFolder "$lastdir" || return 1; }
    fi

    echo "${newdir}" >"$XDG_DATA_HOME/osuconfig/osupath" # 保存以供以后使用
    export OSUPATH="${newdir}"

    longPathsFix || return 1
    saveOsuWinepath || return 1
    Info "osu! 已安装到 '$newdir'！"
    return 0
}

reconfigurePrefix() {
    local freshprefix=''
    local nowinepath=''
    while [[ $# -gt 0 ]]; do
        case "${1}" in
        'nowinepath')
            nowinepath=1
            ;;
        'fresh')
            freshprefix=1
            ;;
        *) ;;
        esac
        shift
    done

    installWinetricks

    [ -n "${freshprefix}" ] && {
        Info "正在检查网络连接.." # 捆绑的前缀安装已经检查过网络，所以这里无需再次检查
        ! ping -c 2 114.114.114.114 >/dev/null 2>&1 && { Error "请先连接互联网再继续 xd。请重新运行脚本" && return 1; }

        [ -d "${WINEPREFIX:?}" ] && rm -rf "${WINEPREFIX}"

        Info "正在使用 winetricks 下载并安装新的前缀。这可能需要一段时间，所以去喝杯咖啡或做点什么吧。"
        "$WINESERVER" -k
        PATH="${SCRDIR}/stuff:${PATH}" WINEDEBUG="fixme-winediag,${WINEDEBUG:-}" WINENTSYNC=0 WINEESYNC=0 WINEFSYNC=0 \
            "$WINETRICKS" -q nocrashdialog autostart_winedbg=disabled dotnet48 dotnet20 gdiplus_winxp meiryo dxvk win10 ||
            { Error "winetricks 灾难性失败！" && return 1; }
    }

    folderFixSetup || return 1
    discordRpc || return 1

    # 使用新文件夹保存 osu winepath，除非是首次安装（需要先安装 osu）
    [ -z "${nowinepath}" ] && { saveOsuWinepath || return 1; }

    $okay
}

# 记住用户是否想要覆盖其本地文件
askConfirmTimeout() {
    [ -z "${1:-}" ] && Info "${FUNCNAME[0]} 缺少参数！？" && exit 1

    local rememberfile="${XDG_DATA_HOME}/osuconfig/rememberupdatechoice"
    touch "${rememberfile}"

    local lastchoice
    lastchoice="$(grep "${1}" "${rememberfile}" | grep -Eo '(y|n)' | tail -n 1)"

    if [ -n "$lastchoice" ] && [ "$lastchoice" = "n" ]; then
        Info "不会更新 ${1}，使用保存在 ${rememberfile} 中的选择"
        Info "如果你改变了主意，请删除此文件。"
        return 1
    elif [ -n "$lastchoice" ] && [ "$lastchoice" = "y" ]; then
        Info "将更新 ${1}，使用保存在 ${rememberfile} 中的选择"
        Info "如果你改变了主意，请删除此文件。"
        return 0
    fi

    local _timeout=${2:-7} # 除非手动指定，否则使用 7 秒超时
    echo -n "$(Info "请选择：(Y/n) [${_timeout}秒] ")"

    read -t "$_timeout" -r prefchoice

    if [[ "$prefchoice" =~ ^(n|N)(o|O)?$ ]]; then
        Info "好的，不会更新 ${1}，将此选择保存到 ${rememberfile}。"
        echo "${1} n" >>"${rememberfile}"
        return 1
    fi
    Info "将更新 ${1}，将此选择保存到 ${rememberfile}。"
    echo "${1} y" >>"${rememberfile}"
    echo ""
    return 0
}

# 更新 osu-wine 启动器本身的辅助函数
launcherUpdate() {
    local launcher="${1}"
    local update_source="$XDG_DATA_HOME/osuconfig/update/osu-wine"
    local backup_path="$XDG_DATA_HOME/osuconfig/osu-wine.bak"

    if [ ! -f "$update_source" ]; then
        Warning "未找到更新源：$update_source"
        return 1
    fi

    if ! cp -f "$launcher" "$backup_path"; then
        Warning "无法在 $backup_path 创建备份"
        return 1
    fi

    if ! cp -f "$update_source" "$launcher"; then
        Warning "无法将更新应用到 $launcher"
        Warning "尝试从备份恢复..."

        if ! cp -f "$backup_path" "$launcher"; then
            Warning "无法恢复备份 - 系统可能处于不一致状态"
            Warning "需要从 $backup_path 手动恢复"
            return 1
        fi
        return 1
    fi

    if ! chmod --reference="$backup_path" "$launcher" 2>/dev/null; then
        chmod +x "$launcher" 2>/dev/null || {
            Warning "无法在 $launcher 上设置可执行权限"
            return 1
        }
    fi
    $okay
}

installYawl() {
    Info "正在安装 yawl..."
    DownloadFile "$YAWLLINK" "/tmp/yawl" || return 1
    mv "/tmp/yawl" "$XDG_DATA_HOME/osuconfig"
    chmod +x "$YAWL_INSTALL_PATH"

    # 也在这里设置 yawl，从基于 umu 的 osu-wine 版本更新时总是需要的
    YAWL_VERBS="make_wrapper=winello;exec=$WINE_INSTALL_PATH/bin/wine;wineserver=$WINE_INSTALL_PATH/bin/wineserver" "$YAWL_INSTALL_PATH"
    YAWL_VERBS="update;verify;exec=/bin/true" "$YAWL_INSTALL_PATH" || { Error "设置 yawl 时出错！" && return 1; }
    $okay
}

# 此函数读取位于 $XDG_DATA_HOME/osuconfig 中的文件
# 以查看是否发布了新版本的 wine-osu。
Update() {
    local launcher_path="${1:-"${LAUNCHERPATH}"}"
    if [ ! -x "$WINE" ]; then
        rm -f "${XDG_DATA_HOME}/osuconfig/rememberupdatechoice"
        installYawl || Info "继续，但某些功能可能已损坏..."
    else
        local INSTALLED_YAWL_VERSION
        INSTALLED_YAWL_VERSION="$(env "YAWL_VERBS=version" "$WINE" 2>/dev/null)"
        if [[ "$INSTALLED_YAWL_VERSION" =~ 0\.5\.* ]]; then
            installYawl || Info "继续，但某些功能可能已损坏..."
        else
            Info "正在检查 yawl 更新..."
            YAWL_VERBS="update" "$WINE" "--version"
        fi
    fi

    # 读取最后安装的版本
    [ -r "$XDG_DATA_HOME/osuconfig/wineverupdate" ] && LASTWINEVERSION=$(</"$XDG_DATA_HOME/osuconfig/wineverupdate")

    if [ "$LASTWINEVERSION" \!= "$WINEVERSION" ]; then
        # 下载 Wine..
        DownloadFile "$WINELINK" "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz" || return 1

        # 这将解压 Wine-osu 并将最后版本设置为下载的版本
        Info "正在更新 Wine-osu"...
        rm -rf "$XDG_DATA_HOME/osuconfig/wine-osu"
        tar -xf "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz" -C "$XDG_DATA_HOME/osuconfig"
        rm -f "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz"

        echo "$WINEVERSION" >"$XDG_DATA_HOME/osuconfig/wineverupdate"
        Info "更新完成！"
        waitWine wineboot -u
    else
        Info "你的 Wine-osu 已经是最新版本！"
    fi

    mkdir -p "$XDG_DATA_HOME/osuconfig/configs" # 创建 configs 目录，如果不存在则复制示例配置
    [ ! -r "$XDG_DATA_HOME/osuconfig/configs/example.cfg" ] && cp "${SCRDIR}/stuff/example.cfg" "$XDG_DATA_HOME/osuconfig/configs/example.cfg"

    # 从 umu-launcher 更新时将需要此文件
    [ ! -r "$XDG_DATA_HOME/osuconfig/.osu-path-winepath" ] && { saveOsuWinepath || return 1; }

    [ -n "$NOLAUNCHERUPDATE" ] && Info "你的 osu-wine 启动器将保持不变。" && $okay

    [ ! -x "${launcher_path}" ] && { Error "无法找到要更新的 osu-wine 启动器的路径。请重新安装 osu-winello。" && return 1; }

    if [ ! -w "${launcher_path}" ]; then
        Warning "注意：${launcher_path} 不可写 - 无法更新 osu-wine 启动器"
        Warning "如果你想要更新启动器，请尝试使用适当的权限运行更新，"
        Warning "   或者将其移动到像 $BINDIR 这样的位置，然后从那里运行。"
        return 0
    fi

    Info "正在更新启动器 (${launcher_path})..."
    if launcherUpdate "${launcher_path}"; then
        Info "启动器更新成功！"
        Info "备份已保存到：$XDG_DATA_HOME/osuconfig/osu-wine.bak"
    else
        Error "启动器更新失败" && return 1
    fi
    $okay
}

# 嗯，简单的安装游戏函数（也实现在 osu-wine --remove 中）
Uninstall() {
    Info "正在卸载图标："
    rm -f "$XDG_DATA_HOME/icons/osu-wine.png"

    Info "正在卸载 .desktop："
    rm -f "$XDG_DATA_HOME/applications/osu-wine.desktop"

    Info "正在卸载游戏脚本、实用程序和 folderfix："
    rm -f "$BINDIR/osu-wine"
    rm -f "$BINDIR/folderfixosu"
    rm -f "$BINDIR/folderfixosu.vbs"
    rm -f "$XDG_DATA_HOME/mime/packages/osuwinello-file-extensions.xml"
    rm -f "$XDG_DATA_HOME/applications/osuwinello-file-extensions-handler.desktop"
    rm -f "$XDG_DATA_HOME/applications/osuwinello-url-handler.desktop"

    Info "正在卸载 wine-osu："
    rm -rf "$XDG_DATA_HOME/osuconfig/wine-osu"

    Info "正在卸载 yawl 和 steam 运行时："
    rm -rf "$XDG_DATA_HOME/yawl"

    read -r -p "$(Info "是否要卸载 Wine 前缀？(y/N)")" wineprch

    if [ "$wineprch" = 'y' ] || [ "$wineprch" = 'Y' ]; then
        rm -rf "$XDG_DATA_HOME/wineprefixes/osu-wineprefix"
    else
        Info "跳过.."
    fi

    read -r -p "$(Info "是否要卸载游戏文件？(y/N)")" choice

    if [ "$choice" = 'y' ] || [ "$choice" = 'Y' ]; then
        read -r -p "$(Info "你确定吗？这将删除你的文件！(y/N)")" choice2

        if [ "$choice2" = 'y' ] || [ "$choice2" = 'Y' ]; then
            Info "正在卸载游戏："
            if [ -e "$XDG_DATA_HOME/osuconfig/osupath" ]; then
                OSUUNINSTALLPATH=$(<"$XDG_DATA_HOME/osuconfig/osupath")
                rm -rf "$OSUUNINSTALLPATH"
                rm -rf "$XDG_DATA_HOME/osuconfig"
            else
                rm -rf "$XDG_DATA_HOME/osuconfig"
            fi
        else
            rm -rf "$XDG_DATA_HOME/osuconfig"
            Info "正在退出.."
        fi
    else
        rm -rf "$XDG_DATA_HOME/osuconfig"
    fi

    Info "卸载完成！"
    return 0
}

SetupReader() {
    local READER_NAME="${1}"
    Info "正在设置 $READER_NAME 包装器..."
    # 首先获取所有需要的路径
    local READER_PATH
    local OSU_WINEDIR
    local OSU_WINEEXE
    READER_PATH="$(WINEDEBUG=-all "$WINE" winepath -w "$XDG_DATA_HOME/osuconfig/$READER_NAME/$READER_NAME.exe" 2>/dev/null)" || { Error "在预期位置未找到 $READER_NAME..." && return 1; }
    { [ -r "$XDG_DATA_HOME/osuconfig/.osu-path-winepath" ] && read -r OSU_WINEDIR <<<"$(cat "$XDG_DATA_HOME/osuconfig/.osu-path-winepath")" &&
        [ -r "$XDG_DATA_HOME/osuconfig/.osu-exe-winepath" ] && read -r OSU_WINEEXE <<<"$(cat "$XDG_DATA_HOME/osuconfig/.osu-exe-winepath")"; } ||
        { Error "你需要完全安装 osu-winello 才能设置 $READER_NAME。\n\t(缺少 $XDG_DATA_HOME/osuconfig/.osu-path-winepath 或 .osu-exe-winepath 。)" && return 1; }

    # 用于在容器中与 osu 一起打开 tosu/gosumemory 的启动器批处理文件，并在 osu! 退出时尝试停止挂起的 gosumemory/tosu 进程（为什么会出现这种情况！？）
    cat >"$OSUPATH/launch_with_memory.bat" <<EOF
@echo off
set NODE_SKIP_PLATFORM_CHECK=1
cd /d "$OSU_WINEDIR"
start "" osu!.exe %*
start /b "" "$READER_PATH"

:loop
tasklist | find "osu!.exe" >nul
if ERRORLEVEL 1 (
    taskkill /F /IM $READER_NAME.exe
    taskkill /F /IM ${READER_NAME}_overlay.exe
    wineboot -e -f
    exit
)
ping -n 5 127.0.0.1 >nul
goto loop
EOF

    Info "$READER_NAME 包装器已启用。正常启动 osu! 即可使用！"
    return 0
}

# 下载 Gosumemory 的简单函数！
Gosumemory() {
    if [ ! -d "$XDG_DATA_HOME/osuconfig/gosumemory" ]; then
        Info "正在下载 gosumemory.."
        mkdir -p "$XDG_DATA_HOME/osuconfig/gosumemory"
        DownloadFile "${GOSUMEMORYLINK}" "/tmp/gosumemory.zip" || return 1
        unzip -d "$XDG_DATA_HOME/osuconfig/gosumemory" -q "/tmp/gosumemory.zip"
        rm "/tmp/gosumemory.zip"
    fi
    SetupReader "gosumemory" || return 1
    $okay
}

tosu() {
    if [ ! -d "$XDG_DATA_HOME/osuconfig/tosu" ]; then
        Info "正在下载 tosu.."
        mkdir -p "$XDG_DATA_HOME/osuconfig/tosu"
        DownloadFile "${TOSULINK}" "/tmp/tosu.zip" || return 1
        unzip -d "$XDG_DATA_HOME/osuconfig/tosu" -q "/tmp/tosu.zip"
        rm "/tmp/tosu.zip"
    fi
    SetupReader "tosu" || return 1
    $okay
}

# 安装 Akatsuki 补丁程序 (https://akatsuki.gg/patcher)
akatsukiPatcher() {
    local AKATSUKI_PATH="$XDG_DATA_HOME/osuconfig/akatsukiPatcher"

    if ! grep -q 'dotnetdesktop6' "$WINEPREFIX/winetricks.log" 2>/dev/null; then
        Info "Akatsuki 补丁程序需要 .NET Desktop Runtime 6，正在使用 winetricks 安装..."
        $WINETRICKS -q -f dotnetdesktop6
    fi

    if [ ! -d "$AKATSUKI_PATH" ]; then
        Info "正在下载补丁程序.."
        mkdir -p "$AKATSUKI_PATH"
        wget --content-disposition -O "$AKATSUKI_PATH/akatsuki_patcher.exe" "$AKATSUKILINK"
    fi

    # 设置常规的 LaunchOsu 设置
    export WINEDEBUG="+timestamp,+pid,+tid,+threadname,+debugstr,+loaddll,+winebrowser,+exec${WINEDEBUG:+,${WINEDEBUG}}"
    WINELLO_LOGS_PATH="${XDG_DATA_HOME}/osuconfig/winello.log"

    Info "正在打开 $AKATSUKI_PATH/akatsuki_patcher.exe .."
    Info "如果补丁程序找不到 osu!，请点击 Locate > My Computer > D:，然后按打开并启动！"
    Info "运行日志位于 ${WINELLO_LOGS_PATH}。如果你在 GitHub 上提交问题或在 Discord 上寻求帮助，请附上此文件。"
    "$WINE" "$AKATSUKI_PATH/akatsuki_patcher.exe" &>>"${WINELLO_LOGS_PATH}" || return 1
    return 0
}

# 安装 osu! Mapping Tools (https://github.com/olibomby/mapping_tools)
mappingTools() {
    local MAPPINGTOOLSPATH="${WINEPREFIX}/drive_c/Program Files/Mapping Tools"
    local OSUPID

    export DOTNET_BUNDLE_EXTRACT_BASE_DIR="C:\\dotnet_tmp"
    export DOTNET_ROOT="C:\\Program Files\\dotnet"
    [ ! -d "${WINEPREFIX}/drive_c/dotnet_tmp" ] && mkdir -p "${WINEPREFIX}/drive_c/dotnet_tmp"
    [ ! -d "${WINEPREFIX}/drive_c/Program Files/dotnet" ] && mkdir -p "${WINEPREFIX}/drive_c/Program Files/dotnet"

    # 禁用 icu.dll 以防止问题
    export WINEDLLOVERRIDES="${WINEDLLOVERRIDES};icu.dll=d"

    if [ ! -d "${MAPPINGTOOLSPATH}" ]; then
        if OSUPID="$(pgrep osu!.exe)"; then Quit "请在首次安装 Mapping Tools 之前关闭 osu!"; fi

        "$WINESERVER" -k

        Info "正在为 Mapping Tools 设置注册表.."
        waitWine reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Avalon.Graphics" /v DisableHWAcceleration /t REG_DWORD /d 1 /f

        Info "正在下载 Mapping Tools，请确认安装程序提示.."
        DownloadFile "${MAPPINGTOOLSLINK}" /tmp/mapping_tools_installer_x64.exe

        waitWine /tmp/mapping_tools_installer_x64.exe
        rm /tmp/mapping_tools_installer_x64.exe
    fi

    if [ -x "$YAWL_INSTALL_PATH" ] && OSUPID="$(pgrep osu!.exe)"; then
        Info "正在启动 Mapping Tools.."
        YAWL_VERBS="enter=$OSUPID" "${WINE_INSTALL_PATH}/bin/wine" "$MAPPINGTOOLSPATH/"'Mapping Tools.exe'
    else
        Quit "请在启动 Mapping Tools 之前启动 osu!"
    fi
}

# 安装用于 Discord RPC 的 rpc-bridge (https://github.com/EnderIce2/rpc-bridge)
discordRpc() {
    Info "正在设置 Discord RPC 集成..."
    if [ -f "${WINEPREFIX}/drive_c/windows/bridge.exe" ]; then
        Info "rpc-bridge (Discord RPC) 已安装，是否要重新安装？"
        askConfirmTimeout "rpc-bridge (Discord RPC)" || return 0
    fi

    # 首先尝试卸载服务
    waitWine reg delete 'HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\rpc-bridge' /f &>/dev/null
    local chk

    DownloadFile "${DISCRPCLINK}" "/tmp/bridge.zip" || return 1

    mkdir -p /tmp/rpc-bridge
    unzip -d /tmp/rpc-bridge -q "/tmp/bridge.zip"
    waitWine /tmp/rpc-bridge/bridge.exe --install
    rm -f "/tmp/bridge.zip"
    rm -rf "/tmp/rpc-bridge"
    $okay
}

folderFixSetup() {
    longPathsFix || return 1
    # 集成原生文件浏览器（灵感来自）Maot：https://gist.github.com/maotovisk/1bf3a7c9054890f91b9234c3663c03a2
    # 这仅涉及注册表键值。
    Info "正在设置原生文件浏览器集成..."

    local VBS_PATH="$XDG_DATA_HOME/osuconfig/folderfixosu.vbs"
    local FALLBACK_PATH="$XDG_DATA_HOME/osuconfig/folderfixosu"
    cp "${SCRDIR}/stuff/folderfixosu.vbs" "${VBS_PATH}"
    cp "${SCRDIR}/stuff/folderfixosu" "${FALLBACK_PATH}"

    local VBS_WINPATH
    local fallback
    VBS_WINPATH="$(WINEDEBUG=-all waitWine winepath.exe -w "${VBS_PATH}" 2>/dev/null)" || fallback="1"
    [ -z "$VBS_WINPATH" ] && fallback="1"

    waitWine reg add "HKEY_CLASSES_ROOT\folder\shell\open\command" /f
    waitWine reg delete "HKEY_CLASSES_ROOT\folder\shell\open\ddeexec" /f
    if [ -z "${fallback:-}" ]; then
        waitWine reg add "HKEY_CLASSES_ROOT\folder\shell\open\command" /f /ve /t REG_SZ /d "wscript.exe \"${VBS_WINPATH//\\/\\\\}\" \"%1\""
    else
        waitWine reg add "HKEY_CLASSES_ROOT\folder\shell\open\command" /f /ve /t REG_SZ /d "${FALLBACK_PATH} xdg-open \"%1\""
    fi

    # 将 .osu 和 .osb 文件与 winebrowser 关联
    waitWine reg add "HKEY_CLASSES_ROOT\\.osu" /f /ve /t REG_SZ /d "osu_winello_file"
    waitWine reg add "HKEY_CLASSES_ROOT\\.osb" /f /ve /t REG_SZ /d "osu_winello_file"

    waitWine reg add "HKEY_CLASSES_ROOT\\osu_winello_file" /f
    waitWine reg add "HKEY_CLASSES_ROOT\\osu_winello_file\\shell\\open\\command" /f
    if [ -z "${fallback:-}" ]; then
        waitWine reg add "HKEY_CLASSES_ROOT\\osu_winello_file\\shell\\open\\command" /f /ve /t REG_SZ /d "wscript.exe \"${VBS_WINPATH//\\/\\\\}\" \"%1\""
    else
        waitWine reg add "HKEY_CLASSES_ROOT\\osu_winello_file\\shell\\open\\command" /f /ve /t REG_SZ /d "${FALLBACK_PATH} xdg-open \"%1\""
    fi
    $okay
}

osuHandlerSetup() {
    Info "正在配置 osu-mime 和 osu-handler..."

    # 从 https://aur.archlinux.org/packages/osu-mime 安装 osu-mime
    DownloadFile "${OSUMIMELINK}" "/tmp/osu-mime.tar.gz" || return 1

    tar -xf "/tmp/osu-mime.tar.gz" -C "/tmp"
    mkdir -p "$XDG_DATA_HOME/mime/packages"
    cp "/tmp/osu-mime/osu-file-extensions.xml" "$XDG_DATA_HOME/mime/packages/osuwinello-file-extensions.xml"
    update-mime-database "$XDG_DATA_HOME/mime"
    rm -f "/tmp/osu-mime.tar.gz"
    rm -rf "/tmp/osu-mime"

    # 从 https://github.com/openglfreak/osu-handler-wine / https://aur.archlinux.org/packages/osu-handler 安装 osu-handler
    # 二进制文件是在 Ubuntu 18.04 上从源代码编译的
    chmod +x "$XDG_DATA_HOME/osuconfig/update/stuff/osu-handler-wine"

    # 为这两个创建条目
    echo "[Desktop Entry]
Type=Application
Name=osu!
MimeType=application/x-osu-skin-archive;application/x-osu-replay;application/x-osu-beatmap-archive;
Exec=$BINDIR/osu-wine --osuhandler %f
NoDisplay=true
StartupNotify=true
Icon=$XDG_DATA_HOME/icons/osu-wine.png" | tee "$XDG_DATA_HOME/applications/osuwinello-file-extensions-handler.desktop" >/dev/null
    chmod +x "$XDG_DATA_HOME/applications/osuwinello-file-extensions-handler.desktop" >/dev/null

    echo "[Desktop Entry]
Type=Application
Name=osu!
MimeType=x-scheme-handler/osu;
Exec=$BINDIR/osu-wine --osuhandler %u
NoDisplay=true
StartupNotify=true
Icon=$XDG_DATA_HOME/icons/osu-wine.png" | tee "$XDG_DATA_HOME/applications/osuwinello-url-handler.desktop" >/dev/null
    chmod +x "$XDG_DATA_HOME/applications/osuwinello-url-handler.desktop" >/dev/null
    update-desktop-database "$XDG_DATA_HOME/applications"

    # 修复在稳定版更新 20250122.1 之后导入谱面/皮肤/osu 链接的问题：https://osu.ppy.sh/home/changelog/stable40/20250122.1
    Info "正在设置文件 (.osz/.osk) 和 url 关联..."

    # 将 osu-handler.reg 文件添加到注册表
    waitWine regedit /s "$XDG_DATA_HOME/osuconfig/update/stuff/osu-handler.reg"
    $okay
}

# 使用 osu-handler-wine 打开文件/链接
osuHandlerHandle() {
    local ARG="${*:-}" OSUPID
    local HANDLERRUN=("$XDG_DATA_HOME/osuconfig/update/stuff/osu-handler-wine")
    [ ! -x "${HANDLERRUN[0]}" ] && chmod +x "${HANDLERRUN[0]}"

    if [ -x "$YAWL_INSTALL_PATH" ] && OSUPID="$(pgrep osu!.exe)"; then
        HANDLERRUN=("env" "YAWL_VERBS=enter=$OSUPID" "$YAWL_INSTALL_PATH" "${HANDLERRUN[0]}")
        echo "正在尝试在运行 osu! 的容器中打开 osu-handler-wine (PID=$OSUPID)" >&2
    else
        HANDLERRUN=("env" "${WINE}") # 如果启动新实例，我们实际上不需要 osu-handler
        echo "正在尝试打开一个新 osu! 实例来处理 ${ARG}" >&2
    fi

    case "$ARG" in
    osu://*)
        echo "正在尝试加载链接 ($ARG).." >&2
        exec "${HANDLERRUN[@]}" 'C:\\windows\\system32\\start.exe' "$ARG"
        ;;
    *.osr | *.osz | *.osk | *.osz2)
        local EXT="${ARG##*.}" FULLARGPATH FILEDIR
        FULLARGPATH="$(realpath "${ARG}")" || FULLARGPATH="${ARG}" # 如果 realpath 失败则回退

        # 另外，将包含目录添加到 PRESSURE_VESSEL_FILESYSTEMS_RW，因为它可能位于其他位置
        FILEDIR="$(realpath "$(dirname "${FULLARGPATH}")")"
        if [ -n "${FILEDIR}" ] && [ "${FILEDIR}" != "/" ]; then
            export PRESSURE_VESSEL_FILESYSTEMS_RW="${PRESSURE_VESSEL_FILESYSTEMS_RW}:${FILEDIR}"
        fi

        echo "正在尝试加载文件 ($FULLARGPATH).." >&2
        exec "${HANDLERRUN[@]}" 'C:\\windows\\system32\\start.exe' "/ProgIDOpen" "osustable.File.$EXT" "$FULLARGPATH"
        ;;
    esac
    # 如果到了这里，意味着 osu-handler 失败/没有匹配到任何情况
    Error "不支持的 osu! 文件 ($ARG) ！" >&2
    Error "请尝试运行 \"bash $SCRPATH fixosuhandler\" ！" >&2
    return 1
}

installWinetricks() {
    if [ ! -x "$WINETRICKS" ]; then
        Info "正在安装 winetricks..."
        DownloadFile "$WINETRICKSLINK" "/tmp/winetricks" || return 1
        mv "/tmp/winetricks" "$XDG_DATA_HOME/osuconfig"
        chmod +x "$WINETRICKS"
        $okay
    fi
    return 0
}

FixUmu() {
    if [ ! -f "$BINDIR/osu-wine" ] || [ -z "${LAUNCHERPATH}" ]; then
        Error "看起来你还没有安装 osu-winello，所以你应该先运行 ./osu-winello.sh。" && return 1
    fi
    Info "看起来你正在从基于 umu-launcher 的 osu-wine 更新，因此我们将尝试运行完整更新..."
    Info "当询问是否更新 'osu-wine' 启动器时，请回答 'yes'"

    Update "${LAUNCHERPATH}" || { Error "更新失败... 请全新安装 osu-winello。" && return 1; }
    $okay
}

FixYawl() {
    if [ ! -f "$BINDIR/osu-wine" ]; then
        Error "看起来你还没有安装 osu-winello，所以你应该先运行 ./osu-winello.sh。" && return 1
    elif [ ! -f "$YAWL_INSTALL_PATH" ]; then
        Error "未找到 yawl，你应该先运行 ./osu-winello.sh。" && return 1
    fi

    Info "正在修复 yawl..."
    YAWL_VERBS="update;verify;exec=/bin/true" "$YAWL_INSTALL_PATH" && chk=$?
    YAWL_VERBS="make_wrapper=winello;exec=$WINE_INSTALL_PATH/bin/wine;wineserver=$WINE_INSTALL_PATH/bin/wineserver" "$YAWL_INSTALL_PATH"
    if [ "${chk}" != 0 ]; then
        Error "似乎没有成功... 再试一次？" && return 1
    else
        Info "yawl 现在应该可以正常工作了。"
    fi
    $okay
}

WineCachySetup() {
    # 首次设置：yawl-winello-cachy
    if [ ! -d "$XDG_DATA_HOME/osuconfig/wine-osu-cachy-10.0" ]; then
        DownloadFile "$WINECACHYLINK" "/tmp/winecachy.tar.xz"
        tar -xf "/tmp/winecachy.tar.xz" -C "$XDG_DATA_HOME/osuconfig"
        rm -f "/tmp/winecachy.tar.xz"

        WINE_INSTALL_PATH="$XDG_DATA_HOME/osuconfig/wine-osu-cachy-10.0"
        YAWL_VERBS="make_wrapper=winello-cachy;exec=$WINE_INSTALL_PATH/bin/wine;wineserver=$WINE_INSTALL_PATH/bin/wineserver" "$YAWL_INSTALL_PATH"
    fi
}

# 帮助！
Help() {
    Info "要安装游戏，请运行 ./osu-winello.sh
          要卸载游戏，请运行 ./osu-winello.sh uninstall
          要重试安装 yawl 相关文件，请运行 ./osu-winello.sh fixyawl
          你可以在 README.md 或 https://github.com/NelloKudo/osu-winello 阅读更多信息"
}

#   =====================================
#   =====================================
#            主脚本
#   =====================================
#   =====================================

case "$1" in
'')
    {
        InitialSetup &&
            InstallWine &&
            FullInstall
    } || exit 1
    ;;

'uninstall')
    Uninstall || exit 1
    ;;

'gosumemory')
    Gosumemory || exit 1
    ;;

'tosu')
    tosu || exit 1
    ;;

'akatsukiPatcher')
    akatsukiPatcher || exit 1
    ;;

'mappingTools')
    mappingTools || exit 1
    ;;

'discordrpc')
    discordRpc || exit 1
    ;;

'fixfolders')
    folderFixSetup || exit 1
    ;;

'fixprefix')
    reconfigurePrefix fresh || exit 1
    ;;

'winecachy-setup')
    WineCachySetup || exit 1
    ;;

# 也捕获 "fixosuhandler"
*osu*handler)
    osuHandlerSetup || exit 1
    ;;

'handle')
    # 应由 osu-handler 桌面文件（或 osu-wine 用于向后兼容）调用
    osuHandlerHandle "${@:2}" || exit 1
    ;;

'installwinetricks')
    installWinetricks || exit 1
    ;;

'changedir')
    installOrChangeDir || exit 1
    ;;

update*)
    Update "${2:-}" || exit 1 # 第二个参数是 osu-wine 启动器的路径，期望由 `osu-wine --update` 调用
    ;;

# "umu" 保留用于从基于 umu-launcher 的 osu-wine 更新时的向后兼容
*umu*)
    FixUmu || exit 1
    ;;

*yawl*)
    FixYawl || exit 1
    ;;

*help* | '-h')
    Help
    ;;

*)
    Info "未知参数：${*}"
    Help
    ;;
esac

# 恭喜你读完了全部！祝你玩 osu 开心！
# （如果你想改进脚本，欢迎随时提交 PR :3）
