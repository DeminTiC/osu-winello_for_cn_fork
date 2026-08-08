#!/usr/bin/env bash

#   =======================================
#   欢迎使用 Winello！
#   本脚本按函数组织，便于阅读和维护。
#   欢迎贡献代码！
#   =======================================

# Wine-osu 当前版本
MAJOR=11
MINOR=12
PATCH=1
WINEVERSION=$MAJOR.$MINOR-$PATCH
LASTWINEVERSION=0

# Wine-osu 镜像链接
WINELINK="https://github.com/NelloKudo/WineBuilder/releases/download/wine-osu-staging-${WINEVERSION}/wine-osu-winello-fonts-wow64-${WINEVERSION}-x86_64.tar.xz"
WINECACHYLINK="https://github.com/NelloKudo/WineBuilder/releases/download/wine-osu-cachyos-v10.0-3/wine-osu-cachy-winello-fonts-wow64-10.0-3-x86_64.tar.xz"

# 其他外部下载版本
DISCRPCBRIDGEVERSION=1.4.1.3
GOSUMEMORYVERSION=1.3.9
TOSUVERSION=4.3.1
YAWLVERSION=0.8.2
MAPPINGTOOLSVERSION=1.12.27

# 其他下载链接
WINETRICKSLINK="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"                 # Winetricks（用于 --fixprefix）
PREFIXLINK="https://github.com/NelloKudo/osu-winello/releases/download/winello-bins/osu-winello-prefix.tar.xz" # 默认 WINEPREFIX
OSUMIMELINK="https://github.com/NelloKudo/osu-winello/releases/download/winello-bins/osu-mime.tar.gz"          # osu-mime（文件关联）
YAWLLINK="https://github.com/whrvt/yawl/releases/download/v${YAWLVERSION}/yawl"                                # yawl（Steam Runtime 下的 Wine 启动器）

OSUDOWNLOADURL="https://m1.ppy.sh/r/osu!install.exe"

DISCRPCLINK="https://github.com/EnderIce2/rpc-bridge/releases/download/v${DISCRPCBRIDGEVERSION}/bridge.zip"
GOSUMEMORYLINK="https://github.com/l3lackShark/gosumemory/releases/download/${GOSUMEMORYVERSION}/gosumemory_windows_amd64.zip"
TOSULINK="https://github.com/tosuapp/tosu/releases/download/v${TOSUVERSION}/tosu-windows-v${TOSUVERSION}.zip"
AKATSUKILINK="https://air_conditioning.akatsuki.gg/loader"
MAPPINGTOOLSLINK="https://github.com/OliBomby/Mapping_Tools/releases/download/v${MAPPINGTOOLSVERSION}/mapping_tools_installer_x64.exe"

# 本仓库的 Git 地址
WINELLOGIT="https://ghproxy.mirror.skybyte.me/https://github.com/DeminTiC/osu-winello_for_cn_fork.git"

# 全局镜像列表（供 get_mirror_url 使用；可由 select_mirror 修改 USE_CDN/GITHUB_MIRROR）
mirror_names=("cdnghproxy" "chenc" "xxooo" "skybyte")
mirror_urls=("https://cdn.gh-proxy.org/" "https://github.chenc.dev/" "https://gh.xxooo.cf/" "https://ghproxy.mirror.skybyte.me/")

# 根据用户选择返回镜像 URL
# 支持的环境变量：
#   USE_CDN   : 设为 1 启用镜像加速（默认 0）
#   GITHUB_MIRROR : 指定镜像源（预定义名称或自定义完整 URL 前缀），未设置且 USE_CDN=1 时默认使用 'ghproxy'
get_mirror_url() {
    local url="$1"
    if [ "${USE_CDN:-0}" != "1" ] || [[ "$url" != *"github.com"* && "$url" != *"raw.githubusercontent.com"* ]]; then
        echo "$url"
        return
    fi

    local selected="${GITHUB_MIRROR:-cdnghproxy}"
    local mirror_prefix=""

    local found=0
    for i in "${!mirror_names[@]}"; do
        if [ "${mirror_names[$i]}" = "$selected" ]; then
            mirror_prefix="${mirror_urls[$i]}"
            found=1
            break
        fi
    done

    if [ $found -eq 0 ]; then
        mirror_prefix="$selected"   # 视为自定义前缀
    fi

    local path="${url#https://}"
    path="${path#http://}"
    echo "${mirror_prefix}${path}"
}

# 新增：将镜像选择抽取为独立函数（供首次安装与后续重配置/修复调用）
select_mirror() {
    # 如果已经通过环境变量显式设置，则跳过交互
    if [ -n "${USE_CDN_OVERRIDE:-}" ]; then
        return 0
    fi

    # 如果已启用镜像或已设置镜像前缀，则跳过交互
    if [ "${USE_CDN:-0}" = "1" ] || [ -n "${GITHUB_MIRROR:-}" ]; then
        return 0
    fi

    Info "选择下载源（若提供的镜像速度不佳，可自定义）："
    echo "1) GitHub 直连 (默认)"
    local total_mirrors=${#mirror_names[@]}
    for i in "${!mirror_names[@]}"; do
        index=$((i + 2))
        echo "$index) ${mirror_names[$i]} 镜像 (${mirror_urls[$i]})"
    done
    local custom_option=$((total_mirrors + 2))
    echo "$custom_option) 自定义镜像前缀"

    # 交互选择
    read -r -p "$(Info "请输入选择 [1-$custom_option]: ")" mirror_choice

    case "$mirror_choice" in
        1|'')
            export USE_CDN=0
            Info "使用直连下载"
            ;;
        "$custom_option")
            export USE_CDN=1
            read -r -p "$(Info "请输入自定义镜像前缀 (例如 https://cdn.gh-proxy.org/): ")" custom_mirror
            if [[ -n "$custom_mirror" ]]; then
                export GITHUB_MIRROR="$custom_mirror"
                Info "已启用自定义镜像: $custom_mirror"
            else
                Info "输入为空，取消启用镜像"
                export USE_CDN=0
            fi
            ;;
        *)
            if [[ "$mirror_choice" =~ ^[0-9]+$ ]] && [ "$mirror_choice" -ge 2 ] && [ "$mirror_choice" -lt "$custom_option" ]; then
                idx=$((mirror_choice - 2))
                export USE_CDN=1
                export GITHUB_MIRROR="${mirror_names[$idx]}"
                Info "已启用 CDN 镜像: ${mirror_names[$idx]} (${mirror_urls[$idx]})"
            else
                Info "无效选择，使用直连"
                export USE_CDN=0
            fi
            ;;
    esac
}

# 脚本所在目录
SCRDIR="$(realpath "$(dirname "$0")")"
# 脚本完整路径
SCRPATH="$(realpath "$0")"

# 导出的全局变量
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export BINDIR="${BINDIR:-$HOME/.local/bin}"

OSUPATH="${OSUPATH:-}" # 可由 osu-wine 启动器或 osuconfig/osupath 提供，首次安装为空（将在 installOrChangeDir 中设置）

# 不要依赖此变量！启动器路径应从 `osu-wine --update` 获取，这里作为后备
if [ -z "${LAUNCHERPATH}" ]; then
    LAUNCHERPATH="$(realpath /proc/$PPID/exe)" || LAUNCHERPATH="$(readlink /proc/$PPID/exe)"
    [[ ! "${LAUNCHERPATH}" =~ .*osu.* ]] && LAUNCHERPATH=
fi
[ -z "${LAUNCHERPATH}" ] && LAUNCHERPATH="$BINDIR/osu-wine"

export WINEDLLOVERRIDES="winemenubuilder.exe=;" # 阻止 Wine 创建 .desktop 文件
export WINEDEBUG="-wineboot,${WINEDEBUG:-}"     # 不显示 "failed to start winemenubuilder"

export WINENTSYNC="${WINENTSYNC:-0}" # 设置相关操作不使用这些同步机制
export WINEFSYNC="${WINEFSYNC:-0}"   # 避免已运行 wineserver 因参数不同而启动失败
export WINEESYNC="${WINEESYNC:-0}"

# 其他本地变量
WINETRICKS="${WINETRICKS:-"$XDG_DATA_HOME/osuconfig/winetricks"}"
YAWL_INSTALL_PATH="${YAWL_INSTALL_PATH:-"$XDG_DATA_HOME/osuconfig/yawl"}"
export WINE="${WINE:-"${YAWL_INSTALL_PATH}-winello"}"
export WINESERVER="${WINESERVER:-"${WINE}server"}"
export WINEPREFIX="${WINEPREFIX:-"$XDG_DATA_HOME/wineprefixes/osu-wineprefix"}"
export WINE_INSTALL_PATH="${WINE_INSTALL_PATH:-"$XDG_DATA_HOME/osuconfig/wine-osu"}"

# 使路径对 pressure-vessel 可见
[ -z "${PRESSURE_VESSEL_FILESYSTEMS_RW}" ] && {
    _mountline="$(df -P "$SCRPATH" 2>/dev/null | tail -1)" && [ -n "${_mountline}" ] && _mainscript_mount="${_mountline##* }:"  # 脚本所在挂载点
    _mountline="$(df -P "$LAUNCHERPATH" 2>/dev/null | tail -1)" && [ -n "${_mountline}" ] && _curdir_mount="${_mountline##* }:" # 当前目录挂载点
    _mountline="$(df -P "$XDG_DATA_HOME" 2>/dev/null | tail -1)" && [ -n "${_mountline}" ] && _home_mount="${_mountline##* }:"  # XDG_DATA_HOME 挂载点
    PRESSURE_VESSEL_FILESYSTEMS_RW+="${_mainscript_mount:-}${_curdir_mount:-}${_home_mount:-}/mnt:/media:/run/media"
    [ -r "$XDG_DATA_HOME/osuconfig/osupath" ] && OSUPATH=$(</"$XDG_DATA_HOME/osuconfig/osupath") &&
        PRESSURE_VESSEL_FILESYSTEMS_RW+=":$(realpath "$OSUPATH"):$(realpath "$OSUPATH"/Songs 2>/dev/null)" # osu 目录和歌曲目录
    export PRESSURE_VESSEL_FILESYSTEMS_RW="${PRESSURE_VESSEL_FILESYSTEMS_RW//\/:/:}"                       # 清理单独的 "/" 挂载
}

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

#   =====================================
#   =====================================
#           安装函数
#   =====================================
#   =====================================

# 信息输出（带颜色）
Info() {
    echo -e '\033[1;34m'"Winello:\033[0m $*"
}

Warning() {
    echo -e '\033[0;33m'"Winello (警告):\033[0m $*"
}

# 退出但不回滚（某些情况下使用）
Quit() {
    echo -e '\033[1;31m'"Winello:\033[0m $*"
    exit 1
}

# 回滚安装（出错时调用）
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
    echo -e '\033[1;31m'"回滚完成，请重新运行 ./osu-winello.sh\033[0m"
    exit 1
}

# 安装错误（调用 Revert）
InstallError() {
    echo -e '\033[1;31m'"脚本失败:\033[0m $*"
    Revert
}

# 其他功能的错误（不退出，由调用者处理）
Error() {
    echo -e '\033[1;31m'"脚本失败:\033[0m $*"
    return 0
}

# 简写（多个函数成功时返回）
okay="eval Info 完成！ && return 0"

wgetcommand="wget -q --show-progress"
_wget() {
    local url="$1"
    local output="$2"
    $wgetcommand "$url" -O "$output" && return 0
    { [ $? = 2 ] && wgetcommand="wget"; } || wgetcommand="wget --no-check-certificate"
    $wgetcommand "$url" -O "$output" && return 0
    wgetcommand='' # 失败，后续改用 curl
    return 1
}

DownloadFile() {
    local original_url="$1"
    local output="$2"

    # 计算经过镜像转换后的实际下载地址
    local actual_url
    actual_url="$(get_mirror_url "$original_url")"

    Info "准备下载："
    Info "  原始 URL: $original_url"
    Info "  实际 URL: $actual_url"
    if [ "${USE_CDN:-0}" = "1" ] && [[ "$original_url" == *"github.com"* || "$original_url" == *"raw.githubusercontent.com"* ]]; then
        Info "注意：已启用镜像 (GITHUB_MIRROR=${GITHUB_MIRROR:-cdnghproxy})，将从镜像下载。"
    fi

    Info "正在下载 $original_url 到 $output..."
    if [ -n "$wgetcommand" ] && command -v wget >/dev/null 2>&1; then
        _wget "$actual_url" "$output" && return 0
    fi
    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$actual_url" -o "$output" && return 0
    fi
    Error "下载 $actual_url 失败，请检查网络连接。"
    return 1
}

# 检测当前运行的 Shell
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
                    bash|zsh|fish|ksh|mksh|dash|tcsh|csh)
                        current_shell="$proc_name"
                        break
                        ;;
                esac
            fi
        else
            break
        fi
    done

    if [ -z "$current_shell" ]; then
        current_shell=$(basename "$SHELL")
    fi

    echo "$current_shell"
}

# 安装前的基本检查
InitialSetup() {
    # 避免以 root 运行
    if [ "$USER" = "root" ]; then InstallError "请不要使用 root 运行本脚本"; fi

    # 检查旧版 osu-wine
    if [ -e /usr/bin/osu-wine ]; then Quit "请在安装前卸载旧版 osu-wine (/usr/bin/osu-wine)！"; fi
    if [ -e "$BINDIR/osu-wine" ]; then Quit "请在安装前卸载 Winello (osu-wine --remove)！"; fi

    Info "欢迎使用本脚本！跟随它安装 osu! :)"

    # 调用独立的镜像选择函数
    select_mirror

    # 检查 $BINDIR 是否在 PATH 中
    mkdir -p "$BINDIR"
    pathcheck=$(echo "$PATH" | grep -q "$BINDIR" && echo "y")

    if [ "$pathcheck" != "y" ]; then
        current_shell=$(detectRunningShell)

        case "$current_shell" in
            bash)
                touch -a "$HOME/.bashrc"
                echo "export PATH=$BINDIR:\$PATH" >>"$HOME/.bashrc"
                Info "已将 $BINDIR 添加到 ~/.bashrc 的 PATH 中（重启 shell 或执行 source ~/.bashrc）"
                ;;
            zsh)
                touch -a "$HOME/.zshrc"
                echo "export PATH=$BINDIR:\$PATH" >>"$HOME/.zshrc"
                Info "已将 $BINDIR 添加到 ~/.zshrc 的 PATH 中（重启 shell 或执行 source ~/.zshrc）"
                ;;
            fish)
                mkdir -p "$HOME/.config/fish" && touch -a "$HOME/.config/fish/config.fish"
                fish -c "fish_add_path $BINDIR/"
                Info "已将 $BINDIR 添加到 fish 的 PATH 中（重启 shell）"
                ;;
            *)
                Warning "无法检测 shell ($current_shell)，请手动将 $BINDIR 添加到 PATH"
                ;;
        esac
    fi

    # 检查网络
    Info "检查网络连接..."
    ! ping -c 2 114.114.114.114 >/dev/null 2>&1 && ! ping -c 2 www.baidu.com >/dev/null 2>&1 && InstallError "请连接网络后重新运行脚本"

    # 检查依赖
    deps=(pgrep realpath wget zenity unzip)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            InstallError "请先安装 $dep 再继续！"
        fi
    done
}

# 等待 wineserver 退出，减少后续步骤的不确定性
waitWine() {
    {
        "$WINESERVER" -w
        "$WINE" "${@:-"--version"}"
    }
    return 0
}

# 安装脚本文件、yawl 和 Wine-osu
InstallWine() {
    # 安装游戏启动器
    Info "正在安装游戏脚本..."
    cp "${SCRDIR}/osu-wine" "$BINDIR/osu-wine" && chmod +x "$BINDIR/osu-wine"

    Info "正在安装图标..."
    mkdir -p "$XDG_DATA_HOME/icons"
    cp "${SCRDIR}/stuff/osu-wine.png" "$XDG_DATA_HOME/icons/osu-wine.png" && chmod 644 "$XDG_DATA_HOME/icons/osu-wine.png"

    Info "正在安装 .desktop 文件..."
    mkdir -p "$XDG_DATA_HOME/applications"
    echo "[Desktop Entry]
Name=osu!(stable)
Comment=osu!(stable) - 节奏只需轻轻一按！
Type=Application
Exec=$BINDIR/osu-wine %U
Icon=$XDG_DATA_HOME/icons/osu-wine.png
Terminal=false
Categories=Wine;Game;" | tee "$XDG_DATA_HOME/applications/osu-wine.desktop" >/dev/null
    chmod +x "$XDG_DATA_HOME/applications/osu-wine.desktop"

    if [ -d "$XDG_DATA_HOME/osuconfig" ]; then
        Info "跳过 osuconfig 目录（已存在）..."
    else
        mkdir "$XDG_DATA_HOME/osuconfig"
    fi

    Info "正在安装 Wine-osu..."
    DownloadFile "$WINELINK" "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz" || InstallError "下载 wine-osu 失败"

    tar -xf "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz" -C "$XDG_DATA_HOME/osuconfig"
    LASTWINEVERSION="$WINEVERSION"
    rm -f "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz"

    # 尽快安装和验证 yawl
    installYawl || Revert

    # 用于更新的脚本副本
    Info "正在安装用于更新的脚本副本..."
    mkdir -p "$XDG_DATA_HOME/osuconfig/update"

    { git clone . "$XDG_DATA_HOME/osuconfig/update" || git clone "${WINELLOGIT}" "$XDG_DATA_HOME/osuconfig/update"; } ||
        InstallError "Git 克隆失败，请检查网络连接"

    git -C "$XDG_DATA_HOME/osuconfig/update" remote set-url origin "${WINELLOGIT}"

    echo "$LASTWINEVERSION" >>"$XDG_DATA_HOME/osuconfig/wineverupdate"
}

# 配置安装游戏文件夹
InitialOsuInstall() {
    local installpath=1
    Info "请选择游戏安装位置：
          1 - 默认路径 ($XDG_DATA_HOME/osu-wine)
          2 - 自定义路径"
    read -r -p "$(Info "请选择 [1-2]: ")" installpath

    case "$installpath" in
    '2')
        installOrChangeDir || return 1
        ;;
    *)
        Info "安装到默认路径 ($XDG_DATA_HOME/osu-wine)"
        installOrChangeDir "$XDG_DATA_HOME/osu-wine" || return 1
        ;;
    esac
    $okay
}

# 完整安装流程
FullInstall() {
    mkdir -p "$XDG_DATA_HOME/osuconfig/configs"
    [ ! -r "$XDG_DATA_HOME/osuconfig/configs/example.cfg" ] && cp "${SCRDIR}/stuff/example.cfg" "$XDG_DATA_HOME/osuconfig/configs/example.cfg"

    Info "正在配置 Wineprefix..."

    local failprefix="false"
    mkdir -p "$XDG_DATA_HOME/wineprefixes"
    if [ -r "$XDG_DATA_HOME/wineprefixes/osu-wineprefix/system.reg" ]; then
        Info "Wineprefix 已存在，是否重新安装？"
        Warning "除非你清楚后果，否则建议重新安装！"
        read -r -p "$(Info "请选择 (y/N): ")" prefchoice
        if [ "$prefchoice" = 'y' ] || [ "$prefchoice" = 'Y' ]; then
            rm -rf "$XDG_DATA_HOME/wineprefixes/osu-wineprefix"
        fi
    fi

    if [ ! -r "$XDG_DATA_HOME/wineprefixes/osu-wineprefix/system.reg" ]; then
        mkdir -p "$HOME/.winellotmp"
        DownloadFile "${PREFIXLINK}" "$HOME/.winellotmp/osu-winello-prefix.tar.xz" || Revert

        if [ "$failprefix" = "true" ]; then
            reconfigurePrefix nowinepath fresh || Revert
        else
            tar -xf "$HOME/.winellotmp/osu-winello-prefix.tar.xz" -C "$XDG_DATA_HOME/wineprefixes"
            mv "$XDG_DATA_HOME/wineprefixes/osu-prefix" "$XDG_DATA_HOME/wineprefixes/osu-wineprefix"
            reconfigurePrefix nowinepath || Revert
        fi
        rm -rf "$HOME/.winellotmp"
    fi

    osuHandlerSetup || Revert

    Info "配置并安装 osu!"
    InitialOsuInstall || Revert

    Info "安装完成！运行 'osu-wine' 即可开始游戏！"
    Warning "如果 'osu-wine' 无法运行，请关闭并重新打开终端。"
    exit 0
}

#   =====================================
#   =====================================
#         安装后功能函数
#   =====================================
#   =====================================

longPathsFix() {
    Info "正在修复长歌曲名称问题（例如因 osu! 文件夹嵌套过深）..."

    # 将默认 wineprefix 用户名替换为当前用户
    sed -i -e "s|nellokudo|${USER}|g" "${WINEPREFIX}"/{userdef.reg,user.reg,system.reg}

    rm -rf "$WINEPREFIX/dosdevices"
    rm -rf "$WINEPREFIX/drive_c/users/nellokudo"
    mkdir -p "$WINEPREFIX/dosdevices"
    ln -s "$WINEPREFIX/drive_c/" "$WINEPREFIX/dosdevices/c:"
    ln -s / "$WINEPREFIX/dosdevices/z:"
    ln -s "$OSUPATH" "$WINEPREFIX/dosdevices/d:" 2>/dev/null # 首次安装时可能失败，无影响
    waitWine wineboot -u
    return 0
}

saveOsuWinepath() {
    local osupath="${OSUPATH}"
    if [ -z "${osupath}" ]; then
        { [ -r "$XDG_DATA_HOME/osuconfig/osupath" ] && osupath=$(<"$XDG_DATA_HOME/osuconfig/osupath"); } || {
            Error "找不到 osu! 路径！" && return 1
        }
    fi

    Info "正在保存 osu! 路径副本..."

    PRESSURE_VESSEL_FILESYSTEMS_RW="$(realpath "$osupath"):$(realpath "$osupath"/Songs 2>/dev/null):${PRESSURE_VESSEL_FILESYSTEMS_RW}"
    export PRESSURE_VESSEL_FILESYSTEMS_RW

    local temp_winepath
    temp_winepath="$(waitWine winepath -w "$osupath")"
    [ -z "${temp_winepath}" ] && Error "无法通过 winepath 获取 osu! 路径，请检查 $osupath/osu!.exe 是否存在" && return 1

    echo -n "${temp_winepath}" >"$XDG_DATA_HOME/osuconfig/.osu-path-winepath"
    echo -n "${temp_winepath}osu!.exe" >"$XDG_DATA_HOME/osuconfig/.osu-exe-winepath"
    $okay
}

deleteFolder() {
    local folder="${1}"
    Info "是否删除之前的安装目录 ${folder}？"
    read -r -p "$(Info "请选择 (y/N): ")" dirchoice

    if [ "$dirchoice" = 'y' ] || [ "$dirchoice" = 'Y' ]; then
        read -r -p "$(Info "确定吗？这将删除你的 osu! 文件！(y/N): ")" dirchoice2
        if [ "$dirchoice2" = 'y' ] || [ "$dirchoice2" = 'Y' ]; then
            rm -rf "${folder}" || { Error "无法删除文件夹！" && return 1; }
            return 0
        fi
    fi
    Info "跳过删除。"
    return 0
}

# 处理 `osu-wine --changedir` 和安装目录设置
installOrChangeDir() {
    local newdir="${1:-}"
    local lastdir="${OSUPATH:-}"
    if [ -z "${newdir}" ]; then
        Info "请选择 osu! 目录："
        newdir="$(zenity --file-selection --directory)"
        [ ! -d "$newdir" ] && { Error "未选择文件夹，请确保 zenity 已安装" && return 1; }
    fi

    [ ! -s "$newdir/osu!.exe" ] && newdir="$newdir/osu!"
    if [ -s "$newdir/osu!.exe" ] || [ "$newdir" = "$lastdir" ]; then
        Info "osu! 已存在..."
    else
        mkdir -p "$newdir"
        DownloadFile "${OSUDOWNLOADURL}" "$newdir/osu!.exe" || return 1

        [ -n "${lastdir}" ] && { deleteFolder "$lastdir" || return 1; }
    fi

    echo "${newdir}" >"$XDG_DATA_HOME/osuconfig/osupath"
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

    # 在重配置前允许用户选择镜像
    select_mirror

    installWinetricks

    [ -n "${freshprefix}" ] && {
        Info "正在检查网络连接..."
        ! ping -c 2 114.114.114.114 >/dev/null 2>&1 && { Error "请连接网络后重新运行脚本" && return 1; }

        [ -d "${WINEPREFIX:?}" ] && rm -rf "${WINEPREFIX}"

        Info "正在下载并使用 winetricks 安装新 prefix，这可能需要一段时间..."
        "$WINESERVER" -k
        PATH="${SCRDIR}/stuff:${PATH}" WINEDEBUG="fixme-winediag,${WINEDEBUG:-}" WINENTSYNC=0 WINEESYNC=0 WINEFSYNC=0 \
            "$WINETRICKS" -q nocrashdialog autostart_winedbg=disabled dotnet48 dotnet20 gdiplus_winxp meiryo dxvk win10 ||
            { Error "winetricks 执行失败！" && return 1; }
    }

    folderFixSetup || return 1
    discordRpc || return 1

    [ -z "${nowinepath}" ] && { saveOsuWinepath || return 1; }

    $okay
}

redownloadPrefix() {
    # 在重新下载前允许用户选择镜像
    select_mirror

    Info "正在检查网络连接..."
    ! ping -c 2 114.114.114.114 >/dev/null 2>&1 && { Error "请连接网络后重新运行脚本" && return 1; }

    [ -d "${WINEPREFIX:?}" ] && rm -rf "${WINEPREFIX}"

    Info "正在下载 prefix，可能需要一段时间..."
    mkdir -p "$HOME/.winellotmp"
    DownloadFile "${PREFIXLINK}" "$HOME/.winellotmp/osu-winello-prefix.tar.xz" || { rm -rf "$HOME/.winellotmp" && return 1; }

    Info "正在解压 prefix..."
    tar -xf "$HOME/.winellotmp/osu-winello-prefix.tar.xz" -C "$XDG_DATA_HOME/wineprefixes" || { rm -rf "$HOME/.winellotmp" && return 1; }
    mv "$XDG_DATA_HOME/wineprefixes/osu-prefix" "$XDG_DATA_HOME/wineprefixes/osu-wineprefix"
    rm -rf "$HOME/.winellotmp"

    reconfigurePrefix || return 1
}

# 询问用户是否覆盖本地文件，并记住选择
askConfirmTimeout() {
    [ -z "${1:-}" ] && Info "${FUNCNAME[0]} 缺少参数！" && exit 1

    local rememberfile="${XDG_DATA_HOME}/osuconfig/rememberupdatechoice"
    touch "${rememberfile}"

    local lastchoice
    lastchoice="$(grep "${1}" "${rememberfile}" | grep -Eo '(y|n)' | tail -n 1)"

    if [ -n "$lastchoice" ] && [ "$lastchoice" = "n" ]; then
        Info "不会更新 ${1}，使用保存在 ${rememberfile} 中的选择"
        Info "如果要更改，请删除该文件。"
        return 1
    elif [ -n "$lastchoice" ] && [ "$lastchoice" = "y" ]; then
        Info "将更新 ${1}，使用保存在 ${rememberfile} 中的选择"
        Info "如果要更改，请删除该文件。"
        return 0
    fi

    local _timeout=${2:-7}
    echo -n "$(Info "请选择 (Y/n) [${_timeout}s] ")"

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

# 更新 osu-wine 启动器本身
launcherUpdate() {
    local launcher="${1}"
    local update_source="$XDG_DATA_HOME/osuconfig/update/osu-wine"
    local backup_path="$XDG_DATA_HOME/osuconfig/osu-wine.bak"

    if [ ! -f "$update_source" ]; then
        Warning "更新源未找到: $update_source"
        return 1
    fi

    if ! cp -f "$launcher" "$backup_path"; then
        Warning "无法创建备份到 $backup_path"
        return 1
    fi

    if ! cp -f "$update_source" "$launcher"; then
        Warning "应用更新到 $launcher 失败"
        Warning "尝试从备份恢复..."

        if ! cp -f "$backup_path" "$launcher"; then
            Warning "恢复备份失败 - 系统可能处于不一致状态"
            Warning "需要手动从 $backup_path 恢复"
            return 1
        fi
        return 1
    fi

    if ! chmod --reference="$backup_path" "$launcher" 2>/dev/null; then
        chmod +x "$launcher" 2>/dev/null || {
            Warning "无法设置 $launcher 的可执行权限"
            return 1
        }
    fi
    $okay
}

# 自动检测发行版并安装 aria2c
auto_install_aria2() {
    local install_cmd=""
    local pkg_manager=""

    if command -v apt-get >/dev/null 2>&1; then
        pkg_manager="apt-get"
        install_cmd="apt-get update && apt-get install -y aria2"
    elif command -v apt >/dev/null 2>&1; then
        pkg_manager="apt"
        install_cmd="apt update && apt install -y aria2"
    elif command -v dnf >/dev/null 2>&1; then
        pkg_manager="dnf"
        install_cmd="dnf install -y aria2 || (dnf install -y epel-release && dnf install -y aria2)"
    elif command -v yum >/dev/null 2>&1; then
        pkg_manager="yum"
        install_cmd="yum install -y aria2 || (yum install -y epel-release && yum install -y aria2)"
    elif command -v pacman >/dev/null 2>&1; then
        pkg_manager="pacman"
        install_cmd="pacman -Sy --noconfirm aria2"
    elif command -v zypper >/dev/null 2>&1; then
        pkg_manager="zypper"
        install_cmd="zypper install -y aria2"
    elif command -v apk >/dev/null 2>&1; then
        pkg_manager="apk"
        install_cmd="apk add aria2"
    elif command -v xbps-install >/dev/null 2>&1; then
        pkg_manager="xbps"
        install_cmd="xbps-install -y aria2"
    elif command -v emerge >/dev/null 2>&1; then
        pkg_manager="emerge"
        install_cmd="emerge --ask=n --autounmask-write y aria2"
    else
        echo "错误：未找到支持的包管理器，请手动安装 aria2c" >&2
        return 1
    fi

    Info "检测到包管理器：$pkg_manager，将使用命令安装 aria2c：$install_cmd"
    if command -v sudo >/dev/null 2>&1; then
        sudo sh -c "$install_cmd"
    else
        sh -c "$install_cmd"
    fi
}

installYawl() {
    Info "正在安装 yawl..."

    DownloadFile "$YAWLLINK" "/tmp/yawl" || return 1
    mv "/tmp/yawl" "$XDG_DATA_HOME/osuconfig"
    chmod +x "$YAWL_INSTALL_PATH"

    # 防止 yawl 自行下载运行时
    local YAWL_CACHE_DIR="$XDG_DATA_HOME/yawl"
    local RUNTIME_FILE_NAME="SteamLinuxRuntime_sniper.tar.xz"
    local RUNTIME_FILE="${YAWL_CACHE_DIR}/${RUNTIME_FILE_NAME}"
    local RUNTIME_URL="https://repo.steampowered.com/steamrt-images-sniper/snapshots/latest-container-runtime-public-beta/${RUNTIME_FILE_NAME}"

    if [ ! -f "$RUNTIME_FILE" ]; then
        mkdir -p "$YAWL_CACHE_DIR"

        if ! command -v aria2c >/dev/null 2>&1; then
            Info "aria2c 未安装，尝试自动安装..."
            if ! auto_install_aria2; then
                Warning "无法自动安装 aria2c，将使用单线程下载（较慢）"
            fi
        fi

        if command -v aria2c >/dev/null 2>&1; then
            Info "使用 aria2c 多线程下载 Steam Linux Runtime..."
            aria2c -x 16 -s 16 -k 1M -d "$YAWL_CACHE_DIR" -o "$RUNTIME_FILE_NAME" "$RUNTIME_URL" \
                || Warning "aria2c 下载失败，将回退至 yawl 默认下载"
        fi
    else
        Info "Steam Linux Runtime 已存在，跳过下载"
    fi

    # 配置 yawl
    YAWL_VERBS="make_wrapper=winello;exec=$WINE_INSTALL_PATH/bin/wine;wineserver=$WINE_INSTALL_PATH/bin/wineserver" "$YAWL_INSTALL_PATH"
    YAWL_VERBS="update;verify;exec=/bin/true" "$YAWL_INSTALL_PATH" || { Error "设置 yawl 失败！" && return 1; }
    $okay
}

# 检查更新
Update() {
    local launcher_path="${1:-"${LAUNCHERPATH}"}"
    if [ ! -x "$WINE" ]; then
        rm -f "${XDG_DATA_HOME}/osuconfig/rememberupdatechoice"
        installYawl || Info "继续，但可能存在问题..."
    else
        local INSTALLED_YAWL_VERSION
        INSTALLED_YAWL_VERSION="$(env "YAWL_VERBS=version" "$WINE" 2>/dev/null)"
        if [[ "$INSTALLED_YAWL_VERSION" =~ 0\.5\.* ]]; then
            installYawl || Info "继续，但可能存在问题..."
        else
            Info "正在检查 yawl 更新..."
            YAWL_VERBS="update" "$WINE" "--version"
        fi
    fi

    [ -r "$XDG_DATA_HOME/osuconfig/wineverupdate" ] && LASTWINEVERSION=$(</"$XDG_DATA_HOME/osuconfig/wineverupdate")

    if [ "$LASTWINEVERSION" \!= "$WINEVERSION" ]; then
        # 在更新前允许用户选择镜像
        select_mirror

        DownloadFile "$WINELINK" "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz" || return 1

        Info "正在更新 Wine-osu..."
        rm -rf "$XDG_DATA_HOME/osuconfig/wine-osu"
        tar -xf "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz" -C "$XDG_DATA_HOME/osuconfig"
        rm -f "/tmp/wine-osu-winello-fonts-wow64-$MAJOR.$MINOR-$PATCH-x86_64.tar.xz"

        echo "$WINEVERSION" >"$XDG_DATA_HOME/osuconfig/wineverupdate"
        Info "更新完成！"
        waitWine wineboot -u
    else
        Info "Wine-osu 已是最新！"
    fi

    mkdir -p "$XDG_DATA_HOME/osuconfig/configs"
    [ ! -r "$XDG_DATA_HOME/osuconfig/configs/example.cfg" ] && cp "${SCRDIR}/stuff/example.cfg" "$XDG_DATA_HOME/osuconfig/configs/example.cfg"

    [ ! -r "$XDG_DATA_HOME/osuconfig/.osu-path-winepath" ] && { saveOsuWinepath || return 1; }

    [ -n "$NOLAUNCHERUPDATE" ] && Info "osu-wine 启动器将保持不变。" && $okay

    [ ! -x "${launcher_path}" ] && { Error "找不到 osu-wine 启动器路径，请重新安装 osu-winello。" && return 1; }

    if [ ! -w "${launcher_path}" ]; then
        Warning "注意：${launcher_path} 不可写，无法更新 osu-wine 启动器"
        Warning "如需更新，请以适当权限运行，或将其移动到 $BINDIR 后再运行。"
        return 0
    fi

    Info "正在更新启动器 (${launcher_path})..."
    if launcherUpdate "${launcher_path}"; then
        Info "启动器更新成功！"
        Info "备份保存至：$XDG_DATA_HOME/osuconfig/osu-wine.bak"
    else
        Error "启动器更新失败" && return 1
    fi
    $okay
}

# 卸载
Uninstall() {
    Info "正在卸载图标..."
    rm -f "$XDG_DATA_HOME/icons/osu-wine.png"

    Info "正在卸载 .desktop 文件..."
    rm -f "$XDG_DATA_HOME/applications/osu-wine.desktop"

    Info "正在卸载游戏脚本、工具和文件夹修复..."
    rm -f "$BINDIR/osu-wine"
    rm -f "$BINDIR/folderfixosu"
    rm -f "$BINDIR/folderfixosu.vbs"
    rm -f "$XDG_DATA_HOME/mime/packages/osuwinello-file-extensions.xml"
    rm -f "$XDG_DATA_HOME/applications/osuwinello-file-extensions-handler.desktop"
    rm -f "$XDG_DATA_HOME/applications/osuwinello-url-handler.desktop"

    Info "正在卸载 wine-osu..."
    rm -rf "$XDG_DATA_HOME/osuconfig/wine-osu"

    Info "正在卸载 yawl 和 Steam Runtime..."
    rm -rf "$XDG_DATA_HOME/yawl"

    read -r -p "$(Info "是否卸载 Wineprefix？ (y/N): ")" wineprch

    if [ "$wineprch" = 'y' ] || [ "$wineprch" = 'Y' ]; then
        rm -rf "$XDG_DATA_HOME/wineprefixes/osu-wineprefix"
    else
        Info "跳过..."
    fi

    read -r -p "$(Info "是否卸载 osu! 游戏文件？ (y/N): ")" choice

    if [ "$choice" = 'y' ] || [ "$choice" = 'Y' ]; then
        read -r -p "$(Info "确定吗？这将删除所有游戏文件！ (y/N): ")" choice2

        if [ "$choice2" = 'y' ] || [ "$choice2" = 'Y' ]; then
            Info "正在卸载游戏..."
            if [ -e "$XDG_DATA_HOME/osuconfig/osupath" ]; then
                OSUUNINSTALLPATH=$(<"$XDG_DATA_HOME/osuconfig/osupath")
                rm -rf "$OSUUNINSTALLPATH"
                rm -rf "$XDG_DATA_HOME/osuconfig"
            else
                rm -rf "$XDG_DATA_HOME/osuconfig"
            fi
        else
            rm -rf "$XDG_DATA_HOME/osuconfig"
            Info "退出..."
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
    local READER_PATH
    local OSU_WINEDIR
    local OSU_WINEEXE
    READER_PATH="$(WINEDEBUG=-all "$WINE" winepath -w "$XDG_DATA_HOME/osuconfig/$READER_NAME/$READER_NAME.exe" 2>/dev/null)" || { Error "在预期位置未找到 $READER_NAME" && return 1; }
    { [ -r "$XDG_DATA_HOME/osuconfig/.osu-path-winepath" ] && read -r OSU_WINEDIR <<<"$(cat "$XDG_DATA_HOME/osuconfig/.osu-path-winepath")" &&
        [ -r "$XDG_DATA_HOME/osuconfig/.osu-exe-winepath" ] && read -r OSU_WINEEXE <<<"$(cat "$XDG_DATA_HOME/osuconfig/.osu-exe-winepath")"; } ||
        { Error "你需要先完全安装 osu-winello 才能设置 $READER_NAME。\n\t（缺少 $XDG_DATA_HOME/osuconfig/.osu-path-winepath 或 .osu-exe-winepath）" && return 1; }

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

Gosumemory() {
    if [ ! -d "$XDG_DATA_HOME/osuconfig/gosumemory" ]; then
        Info "正在下载 gosumemory..."
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
        Info "正在下载 tosu..."
        mkdir -p "$XDG_DATA_HOME/osuconfig/tosu"
        DownloadFile "${TOSULINK}" "/tmp/tosu.zip" || return 1
        unzip -d "$XDG_DATA_HOME/osuconfig/tosu" -q "/tmp/tosu.zip"
        rm "/tmp/tosu.zip"
    fi
    SetupReader "tosu" || return 1
    $okay
}

akatsukiPatcher() {
    local AKATSUKI_PATH="$XDG_DATA_HOME/osuconfig/akatsukiPatcher"

    if ! grep -q 'dotnetdesktop6' "$WINEPREFIX/winetricks.log" 2>/dev/null; then
        Info "Akatsuki Patcher 需要 .NET Desktop Runtime 6，正在通过 winetricks 安装..."
        $WINETRICKS -q -f dotnetdesktop6
    fi

    if [ ! -d "$AKATSUKI_PATH" ]; then
        Info "正在下载 patcher..."
        mkdir -p "$AKATSUKI_PATH"
        wget --content-disposition -O "$AKATSUKI_PATH/akatsuki_patcher.exe" "$AKATSUKILINK"
    fi

    export WINEDEBUG="+timestamp,+pid,+tid,+threadname,+debugstr,+loaddll,+winebrowser,+exec${WINEDEBUG:+,${WINEDEBUG}}"
    WINELLO_LOGS_PATH="${XDG_DATA_HOME}/osuconfig/winello.log"

    Info "正在打开 $AKATSUKI_PATH/akatsuki_patcher.exe ..."
    Info "如果 patcher 找不到 osu!，请点击 Locate > My Computer > D:，然后按 open 并启动！"
    Info "运行日志位于 ${WINELLO_LOGS_PATH}，如遇到问题可附上此文件。"
    "$WINE" "$AKATSUKI_PATH/akatsuki_patcher.exe" &>>"${WINELLO_LOGS_PATH}" || return 1
    return 0
}

mappingTools() {
    local MAPPINGTOOLSPATH="${WINEPREFIX}/drive_c/Program Files/Mapping Tools"
    local OSUPID

    export DOTNET_BUNDLE_EXTRACT_BASE_DIR="C:\\dotnet_tmp"
    export DOTNET_ROOT="C:\\Program Files\\dotnet"
    [ ! -d "${WINEPREFIX}/drive_c/dotnet_tmp" ] && mkdir -p "${WINEPREFIX}/drive_c/dotnet_tmp"
    [ ! -d "${WINEPREFIX}/drive_c/Program Files/dotnet" ] && mkdir -p "${WINEPREFIX}/drive_c/Program Files/dotnet"

    export WINEDLLOVERRIDES="${WINEDLLOVERRIDES};icu.dll=d"

    if [ ! -d "${MAPPINGTOOLSPATH}" ]; then
        if OSUPID="$(pgrep osu!.exe)"; then Quit "首次安装 Mapping Tools 前请先关闭 osu!"; fi

        "$WINESERVER" -k

        Info "正在为 Mapping Tools 设置注册表..."
        waitWine reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Avalon.Graphics" /v DisableHWAcceleration /t REG_DWORD /d 1 /f

        Info "正在下载 Mapping Tools，请确认安装程序提示..."
        DownloadFile "${MAPPINGTOOLSLINK}" /tmp/mapping_tools_installer_x64.exe

        waitWine /tmp/mapping_tools_installer_x64.exe
        rm /tmp/mapping_tools_installer_x64.exe
    fi

    if [ -x "$YAWL_INSTALL_PATH" ] && OSUPID="$(pgrep osu!.exe)"; then
        Info "正在启动 Mapping Tools..."
        YAWL_VERBS="enter=$OSUPID" "${WINE_INSTALL_PATH}/bin/wine" "$MAPPINGTOOLSPATH/"'Mapping Tools.exe'
    else
        Quit "请先启动 osu! 再启动 Mapping Tools！"
    fi
}

discordRpc() {
    Info "正在设置 Discord RPC 集成..."
    if [ -f "${WINEPREFIX}/drive_c/windows/bridge.exe" ]; then
        Info "rpc-bridge (Discord RPC) 已安装，是否重新安装？"
        askConfirmTimeout "rpc-bridge (Discord RPC)" || return 0
    fi

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
    Info "正在设置原生文件管理器集成..."

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

    DownloadFile "${OSUMIMELINK}" "/tmp/osu-mime.tar.gz" || return 1

    tar -xf "/tmp/osu-mime.tar.gz" -C "/tmp"
    mkdir -p "$XDG_DATA_HOME/mime/packages"
    cp "/tmp/osu-mime/osu-file-extensions.xml" "$XDG_DATA_HOME/mime/packages/osuwinello-file-extensions.xml"
    update-mime-database "$XDG_DATA_HOME/mime"
    rm -f "/tmp/osu-mime.tar.gz"
    rm -rf "/tmp/osu-mime"

    chmod +x "$XDG_DATA_HOME/osuconfig/update/stuff/osu-handler-wine"

    echo "[Desktop Entry]
Type=Application
Name=osu!
MimeType=application/x-osu-skin-archive;application/x-osu-replay;application/x-osu-beatmap-archive;
Exec=$BINDIR/osu-wine --osuhandler %f
NoDisplay=true
StartupNotify=true
Icon=$XDG_DATA_HOME/icons/osu-wine.png" | tee "$XDG_DATA_HOME/applications/osuwinello-file-extensions-handler.desktop" >/dev/null
    chmod +x "$XDG_DATA_HOME/applications/osuwinello-file-extensions-handler.desktop"

    echo "[Desktop Entry]
Type=Application
Name=osu!
MimeType=x-scheme-handler/osu;
Exec=$BINDIR/osu-wine --osuhandler %u
NoDisplay=true
StartupNotify=true
Icon=$XDG_DATA_HOME/icons/osu-wine.png" | tee "$XDG_DATA_HOME/applications/osuwinello-url-handler.desktop" >/dev/null
    chmod +x "$XDG_DATA_HOME/applications/osuwinello-url-handler.desktop"
    update-desktop-database "$XDG_DATA_HOME/applications"

    Info "正在设置文件 (.osz/.osk) 和 URL 关联..."

    waitWine regedit /s "$XDG_DATA_HOME/osuconfig/update/stuff/osu-handler.reg"
    $okay
}

osuHandlerHandle() {
    local ARG="${*:-}" OSUPID
    local -a PRE_ARGS
    local HANDLERRUN=("$XDG_DATA_HOME/osuconfig/update/stuff/osu-handler-wine")
    [ ! -x "${HANDLERRUN[0]}" ] && chmod +x "${HANDLERRUN[0]}"

    if [ -x "$YAWL_INSTALL_PATH" ] && OSUPID="$(pgrep osu!.exe)"; then
        HANDLERRUN=("env" "YAWL_VERBS=enter=$OSUPID" "$YAWL_INSTALL_PATH" "${HANDLERRUN[0]}")
        echo "尝试在正在运行的 osu! 容器 (PID=$OSUPID) 中打开 osu-handler-wine" >&2
    else
        IFS=" " read -r -a PRE_ARGS <<<"env ${PRE_LAUNCH_ARGS}"
        HANDLERRUN=("${PRE_ARGS[@]}" "${WINE}")
        echo "尝试启动新的 osu! 实例来处理 ${ARG}" >&2
    fi

    case "$ARG" in
    osu://*)
        echo "尝试加载链接 ($ARG)..." >&2
        exec "${HANDLERRUN[@]}" 'C:\\windows\\system32\\start.exe' "$ARG"
        ;;
    *.osr | *.osz | *.osk | *.osz2)
        local EXT="${ARG##*.}" FULLARGPATH FILEDIR
        FULLARGPATH="$(realpath "${ARG}")" || FULLARGPATH="${ARG}"

        FILEDIR="$(realpath "$(dirname "${FULLARGPATH}")")"
        if [ -n "${FILEDIR}" ] && [ "${FILEDIR}" != "/" ]; then
            export PRESSURE_VESSEL_FILESYSTEMS_RW="${PRESSURE_VESSEL_FILESYSTEMS_RW}:${FILEDIR}"
        fi

        echo "尝试加载文件 ($FULLARGPATH)..." >&2
        exec "${HANDLERRUN[@]}" 'C:\\windows\\system32\\start.exe' "/ProgIDOpen" "osustable.File.$EXT" "$FULLARGPATH"
        ;;
    esac
    Error "不支持的 osu! 文件 ($ARG)！" >&2
    Error "请尝试运行 \"bash $SCRPATH fixosuhandler\"！" >&2
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
        Error "你似乎尚未安装 osu-winello，请先运行 ./osu-winello.sh 进行安装。" && return 1
    fi
    Info "你正在从基于 umu-launcher 的 osu-wine 更新，我们将尝试执行完整更新..."
    Info "当询问是否更新 'osu-wine' 启动器时，请回答 'yes'"

    Update "${LAUNCHERPATH}" || { Error "更新失败... 请重新安装 osu-winello。" && return 1; }
    $okay
}

FixYawl() {
    if [ ! -f "$BINDIR/osu-wine" ]; then
        Error "你似乎尚未安装 osu-winello，请先运行 ./osu-winello.sh 进行安装。" && return 1
    elif [ ! -f "$YAWL_INSTALL_PATH" ]; then
        Error "未找到 yawl，请先运行 ./osu-winello.sh 进行安装。" && return 1
    fi

    # 在修复 yawl 之前允许用户选择镜像
    select_mirror

    Info "正在修复 yawl..."
    YAWL_VERBS="update;verify;exec=/bin/true" "$YAWL_INSTALL_PATH" && chk=$?
    YAWL_VERBS="make_wrapper=winello;exec=$WINE_INSTALL_PATH/bin/wine;wineserver=$WINE_INSTALL_PATH/bin/wineserver" "$YAWL_INSTALL_PATH"
    if [ "${chk}" != 0 ]; then
        Error "修复似乎没有成功... 请重试？" && return 1
    else
        Info "yawl 应该已修复完成。"
    fi
    $okay
}

WineCachySetup() {
    if [ ! -d "$XDG_DATA_HOME/osuconfig/wine-osu-cachy-10.0" ]; then
        # 重新选择镜像以用于下载 cachy 包
        select_mirror

        DownloadFile "$WINECACHYLINK" "/tmp/winecachy.tar.xz"
        tar -xf "/tmp/winecachy.tar.xz" -C "$XDG_DATA_HOME/osuconfig"
        rm -f "/tmp/winecachy.tar.xz"

        WINE_INSTALL_PATH="$XDG_DATA_HOME/osuconfig/wine-osu-cachy-10.0"
        YAWL_VERBS="make_wrapper=winello-cachy;exec=$WINE_INSTALL_PATH/bin/wine;wineserver=$WINE_INSTALL_PATH/bin/wineserver" "$YAWL_INSTALL_PATH"
    fi
}

detectAbsoluteTabletHack() {
    [ -n "${WINE_ENABLE_ABS_TABLET_HACK+x}" ] && return 1

    if [ "${XDG_SESSION_TYPE:-}" != "wayland" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
        return 1
    fi

    [ -r /proc/bus/input/devices ] || return 1
    grep -q 'Name="OpenTabletDriver Virtual Tablet"' /proc/bus/input/devices || return 1

    local settings_json
    for settings_json in \
        "$HOME/.config/OpenTabletDriver/settings.json" \
        "$HOME/.var/app/net.opentabletdriver.OpenTabletDriver/config/OpenTabletDriver/settings.json"; do
        [ -r "$settings_json" ] || continue
        grep -Eq '"Enable"[[:space:]]*:[[:space:]]*true' "$settings_json" &&
            grep -Eq '"Path"[[:space:]]*:[[:space:]]*".*\.AbsoluteMode"' "$settings_json" &&
            return 0
    done
    return 1
}

# 帮助信息
Help() {
    Info "使用方法：
          ./osu-winello.sh                  # 安装游戏
          ./osu-winello.sh uninstall        # 卸载游戏
          ./osu-winello.sh fixyawl          # 重新安装 yawl 相关文件
          更多信息请参阅 README.md 或 https://github.com/NelloKudo/osu-winello"
}

#   =====================================
#   =====================================
#            主脚本入口
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
    if [ "${2:-}" = "--redl" ]; then
        redownloadPrefix || exit 1
    else
        reconfigurePrefix fresh || exit 1
    fi
    ;;

'winecachy-setup')
    WineCachySetup || exit 1
    ;;

*osu*handler)
    osuHandlerSetup || exit 1
    ;;

'handle')
    osuHandlerHandle "${@:2}" || exit 1
    ;;

'installwinetricks')
    installWinetricks || exit 1
    ;;

'changedir')
    installOrChangeDir || exit 1
    ;;

update*)
    Update "${2:-}" || exit 1
    ;;

*umu*)
    FixUmu || exit 1
    ;;

*yawl*)
    FixYawl || exit 1
    ;;

'detectabsolutetablethack')
    detectAbsoluteTabletHack || exit 1
    ;;

*help* | '-h')
    Help
    ;;

*)
    Info "未知参数：${*}"
    Help
    ;;
esac

# 祝你玩得愉快！
