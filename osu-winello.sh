#!/usr/bin/env bash

# =========================================
#   osu-winello-umu 安装脚本
#   用法：./osu-winello.sh [uninstall|update|gosumemory|help]
# =========================================

# ---------- 下载地址集中管理 ----------
PROTONVERSION=9.16
PROTONLINK="https://github.com/whrvt/umubuilder/releases/download/proton-osu-9-16/proton-osu-9-16.tar.xz"

# Wine 容器（预配置前缀）
PREFIXLINK="https://github.com/DeminTiC/TOPiC-s-Asset-Dictionary/raw/refs/heads/main/Proton-osu/osu-winello-prefix.tar.xz"

# osu!mime 和 osu-handler
OSU_MIME_LINK="https://aur.archlinux.org/cgit/aur.git/snapshot/osu-mime.tar.gz"
OSU_HANDLER_LINK="https://github.com/DeminTiC/osu-winello_for_cn_fork/blob/winello-umu/stuff/osu-handler-wine"

# Discord RPC 支持
WINESTREAMPROXY_LINK="https://github.com/openglfreak/winestreamproxy/releases/download/v2.0.3/winestreamproxy-2.0.3-amd64.tar.gz"

# osu! 安装程序
OSU_INSTALLER_LINK="http://m1.ppy.sh/r/osu!install.exe"

# gosumemory（内存读取工具）
GOSUMEMORY_LINK="https://github.com/l3lackShark/gosumemory/releases/download/1.3.9/gosumemory_windows_amd64.zip"

# 代理配置文件路径
PROXY_CONFIG="$HOME/.local/share/osuconfig/proxy.conf"
GITHUB_PROXY=""          # 存储代理前缀，空表示不使用代理
GITHUB_PROXY_SET=0       # 是否已初始化代理配置

# ---------- 代理初始化（首次询问并保存）----------
InitProxy() {
    # 已经初始化过就跳过
    [ "$GITHUB_PROXY_SET" -eq 1 ] && return
    # 配置文件存在就直接读取
    if [ -f "$PROXY_CONFIG" ]; then
        GITHUB_PROXY=$(cat "$PROXY_CONFIG")
        GITHUB_PROXY_SET=1
        return
    fi

    echo -e '\033[1;33mWinello: 是否使用 GitHub 加速代理（国内用户推荐）？\033[0m'
    read -r -p "启用代理? (y/N): " proxy_choice
    if [[ "$proxy_choice" =~ ^[Yy]$ ]]; then
        GITHUB_PROXY="https://gh.xxooo.cf/"
        echo -e '\033[1;32m已启用 GitHub 代理：'"$GITHUB_PROXY"\033[0m
    else
        GITHUB_PROXY=""
        echo -e '\033[1;32m将直接连接 GitHub（不使用代理）\033[0m'
    fi
    mkdir -p "$(dirname "$PROXY_CONFIG")"
    echo "$GITHUB_PROXY" > "$PROXY_CONFIG"
    GITHUB_PROXY_SET=1
}

# ---------- 带代理支持的下载函数 ----------
downloadfile() {
    local url="$1"
    local output="$2"
    local retry=0
    local max_retries=2

    # 如果启用了代理且 URL 来自 GitHub，则加上代理前缀
    if [ -n "$GITHUB_PROXY" ]; then
        if [[ "$url" =~ github\.com ]] || [[ "$url" =~ raw\.githubusercontent\.com ]] || [[ "$url" =~ gitlab\.com ]]; then
            url="${GITHUB_PROXY}${url}"
        fi
    fi

    Info "正在下载: $(basename "$output")"
    while [ $retry -lt $max_retries ]; do
        if [ $retry -eq 0 ]; then
            wget -O "$output" "$url" && return 0
        else
            wget --no-check-certificate -O "$output" "$url" && return 0
        fi
        retry=$((retry + 1))
    done
    Error "下载失败（多次重试后）: $url"
}

# ---------- 基础函数 ----------
Info() {
    echo -e '\033[1;34mWinello:\033[0m '"$*"
}

Quit() {
    echo -e '\033[1;31mWinello:\033[0m '"$*"
    exit 1
}

Error() {
    echo -e '\033[1;31m脚本出错:\033[0m '"$*"
    Revert
    exit 1
}

Revert() {
    echo -e '\033[1;31m正在回滚安装……\033[0m'
    rm -f "$HOME/.local/share/icons/osu-wine.png"
    rm -f "$HOME/.local/share/applications/osu-wine.desktop"
    rm -f "$HOME/.local/bin/osu-wine"
    rm -rf "$HOME/.local/share/osuconfig"
    rm -f "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz"
    rm -f "/tmp/osu-mime.tar.gz"
    rm -rf "/tmp/osu-mime"
    rm -f "$HOME/.local/share/mime/packages/osuwinello-file-extensions.xml"
    rm -f "$HOME/.local/share/applications/osuwinello-file-extensions-handler.desktop"
    rm -f "$HOME/.local/share/applications/osuwinello-url-handler.desktop"
    rm -f "/tmp/winestreamproxy-2.0.3-amd64.tar.gz"
    rm -rf "/tmp/winestreamproxy"
    rm -rf "$HOME/.winellotmp"
    echo -e '\033[1;31m回滚完成，请重新运行脚本\033[0m'
}

# ---------- 卸载功能（原脚本缺失）----------
Uninstall() {
    Info "开始卸载 Winello / osu-wine……"
    Revert
    # 额外删除游戏目录（询问用户）
    if [ -d "$HOME/.local/share/osu-wine" ]; then
        read -r -p "是否删除游戏目录 ($HOME/.local/share/osu-wine) ？(y/N): " delgame
        if [[ "$delgame" =~ ^[Yy]$ ]]; then
            rm -rf "$HOME/.local/share/osu-wine"
            Info "游戏目录已删除"
        fi
    fi
    Info "卸载完成。"
    exit 0
}

# ---------- 环境检查与准备 ----------
InitialSetup() {
    if [ "$USER" = "root" ]; then
        Error "请不要使用 root 用户运行此脚本"
    fi

    if [ -e /usr/bin/osu-wine ]; then
        Quit "请先卸载旧版 osu-wine（位于 /usr/bin/osu-wine）再安装"
    fi
    if [ -e "$HOME/.local/bin/osu-wine" ]; then
        Quit "请先卸载 Winello（运行 osu-wine --remove）再安装"
    fi

    Info "欢迎使用本脚本，将帮你安装 osu!（wine 版）"

    # 确保 ~/.local/bin 在 PATH 中
    mkdir -p "$HOME/.local/bin"
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        case "$SHELL" in
            *bash)
                echo "export PATH=\"$HOME/.local/bin:\$PATH\"" >> "$HOME/.bashrc"
                ;;
            *zsh)
                echo "export PATH=\"$HOME/.local/bin:\$PATH\"" >> "$HOME/.zshrc"
                ;;
            *fish)
                mkdir -p "$HOME/.config/fish"
                echo "fish_add_path ~/.local/bin" >> "$HOME/.config/fish/config.fish"
                ;;
        esac
        Info "已将 ~/.local/bin 加入 PATH，请重启终端或重新加载配置文件"
    fi

    Info "正在检查网络……"
    if ! ping -c 1 114.114.114.114 >/dev/null 2>&1 && ! ping -c 1 bing.com >/dev/null 2>&1; then
        Error "请连接互联网后再运行"
    fi

    # 必需的命令
    deps=(wget zenity unzip tar)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            Error "请先安装 $dep 再继续"
        fi
    done

    if ! command -v update-mime-database >/dev/null 2>&1; then
        Error "请先安装 update-mime-database（通常属于 shared-mime-info 软件包）"
    fi

    # 初始化代理设置
    InitProxy
}

# ---------- 安装 Proton-osu 和启动脚本 ----------
InstallProton() {
    Info "正在安装启动脚本……"
    # 获取脚本所在目录，以便找到资源文件
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cp "$SCRIPT_DIR/osu-wine" "$HOME/.local/bin/osu-wine" && chmod +x "$HOME/.local/bin/osu-wine"

    Info "正在安装图标……"
    mkdir -p "$HOME/.local/share/icons"
    cp "$SCRIPT_DIR/stuff/osu-wine.png" "$HOME/.local/share/icons/osu-wine.png" && chmod 644 "$HOME/.local/share/icons/osu-wine.png"

    Info "正在安装 .desktop 文件……"
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/osu-wine.desktop" << EOF
[Desktop Entry]
Name=osu!
Comment=osu! - 节奏游戏，只需点击！
Type=Application
Exec=$HOME/.local/bin/osu-wine %U
Icon=$HOME/.local/share/icons/osu-wine.png
Terminal=false
Categories=Wine;Game;
EOF
    chmod +x "$HOME/.local/share/applications/osu-wine.desktop"

    mkdir -p "$HOME/.local/share/osuconfig"

    Info "正在安装 Proton-osu……"
    downloadfile "$PROTONLINK" "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz"
    tar -xf "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz" -C "$HOME/.local/share/osuconfig"
    echo "$PROTONVERSION" > "$HOME/.local/share/osuconfig/protonverupdate"
    rm -f "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz"

    Info "正在安装 umu-launcher……"
    cp "$SCRIPT_DIR/stuff/umu-run" "$HOME/.local/share/osuconfig/"
    chmod +x "$HOME/.local/share/osuconfig/umu-run"
    export UMU_RUN="$HOME/.local/share/osuconfig/umu-run"
    export GAMEID="osu-wine-umu"

    # 保存一份脚本自身，用于后续更新
    mkdir -p "$HOME/.local/share/osuconfig/update"
    if [ -n "$GITHUB_PROXY" ]; then
        Info "使用代理下载脚本仓库（zip 包）"
        downloadfile "https://github.com/NelloKudo/osu-winello/archive/refs/heads/main.zip" "/tmp/osu-winello-main.zip"
        unzip -q "/tmp/osu-winello-main.zip" -d "/tmp"
        mv "/tmp/osu-winello-main" "$HOME/.local/share/osuconfig/update"
        rm -f "/tmp/osu-winello-main.zip"
    else
        git clone https://github.com/NelloKudo/osu-winello.git "$HOME/.local/share/osuconfig/update" || Error "git 克隆失败，请检查网络"
    fi
}

# ---------- 选择游戏安装目录 ----------
ConfigurePath() {
    Info "配置 osu! 文件夹位置："
    echo "  1 - 默认路径 (~/.local/share/osu-wine)"
    echo "  2 - 自定义路径"
    read -r -p "请选择 (1/2): " installpath

    case "$installpath" in
        1)
            GAMEDIR="$HOME/.local/share/osu-wine"
            ;;
        2)
            GAMEDIR="$(zenity --file-selection --directory --title="选择 osu! 安装目录")"
            if [ -z "$GAMEDIR" ]; then
                Info "未选择目录，使用默认路径"
                GAMEDIR="$HOME/.local/share/osu-wine"
            fi
            ;;
        *)
            Info "无效选项，使用默认路径"
            GAMEDIR="$HOME/.local/share/osu-wine"
            ;;
    esac

    mkdir -p "$GAMEDIR"
    # 判断现有目录名（osu! 或 OSU）
    if [ -d "$GAMEDIR/OSU" ]; then
        OSUPATH="$GAMEDIR/OSU"
    elif [ -d "$GAMEDIR/osu!" ]; then
        OSUPATH="$GAMEDIR/osu!"
    else
        mkdir -p "$GAMEDIR/osu!"
        OSUPATH="$GAMEDIR/osu!"
    fi

    echo "$OSUPATH" > "$HOME/.local/share/osuconfig/osupath"
    Info "游戏目录设为: $OSUPATH"
}

# ---------- 完整安装（MIME、前缀、RPC 等）----------
FullInstall() {
    InitProxy

    Info "正在配置 osu! 文件关联 (mime) 和 URL 处理器……"

    # 安装 osu-mime
    downloadfile "$OSU_MIME_LINK" "/tmp/osu-mime.tar.gz"
    tar -xf "/tmp/osu-mime.tar.gz" -C "/tmp"
    mkdir -p "$HOME/.local/share/mime/packages"
    cp "/tmp/osu-mime/osu-file-extensions.xml" "$HOME/.local/share/mime/packages/osuwinello-file-extensions.xml"
    update-mime-database "$HOME/.local/share/mime"
    rm -f "/tmp/osu-mime.tar.gz"
    rm -rf "/tmp/osu-mime"

    # 安装 osu-handler-wine
    downloadfile "$OSU_HANDLER_LINK" "$HOME/.local/share/osuconfig/osu-handler-wine"
    chmod +x "$HOME/.local/share/osuconfig/osu-handler-wine"

    # 文件关联 desktop 文件
    cat > "$HOME/.local/share/applications/osuwinello-file-extensions-handler.desktop" << EOF
[Desktop Entry]
Type=Application
Name=osu!
MimeType=application/x-osu-skin-archive;application/x-osu-replay;application/x-osu-beatmap-archive;
Exec=$HOME/.local/share/osuconfig/osu-handler-wine %f
NoDisplay=true
StartupNotify=true
Icon=$HOME/.local/share/icons/osu-wine.png
EOF
    chmod +x "$HOME/.local/share/applications/osuwinello-file-extensions-handler.desktop"

    # URL 关联 desktop 文件
    cat > "$HOME/.local/share/applications/osuwinello-url-handler.desktop" << EOF
[Desktop Entry]
Type=Application
Name=osu!
MimeType=x-scheme-handler/osu;
Exec=$HOME/.local/share/osuconfig/osu-handler-wine %u
NoDisplay=true
StartupNotify=true
Icon=$HOME/.local/share/icons/osu-wine.png
EOF
    chmod +x "$HOME/.local/share/applications/osuwinello-url-handler.desktop"

    update-desktop-database "$HOME/.local/share/applications"

    # 配置 Wine 容器（前缀）
    export PROTONPATH="$HOME/.local/share/osuconfig/proton-osu"
    export WINEPREFIX="$HOME/.local/share/wineprefixes/osu-wineprefix"

    Info "正在配置 Wine 运行环境……"
    mkdir -p "$HOME/.local/share/wineprefixes"

    # 如果已有前缀，询问是否覆盖
    if [ -d "$WINEPREFIX" ]; then
        read -r -p "Wine 前缀已存在，是否重新安装？(y/N): " prefchoice
        if [[ "$prefchoice" =~ ^[Yy]$ ]]; then
            rm -rf "$WINEPREFIX"
        fi
    fi

    if [ ! -d "$WINEPREFIX" ]; then
        # 使用 downloadfile 下载预配置前缀（支持代理）
        mkdir -p "$HOME/.winellotmp"
        downloadfile "$PREFIXLINK" "$HOME/.winellotmp/osu-winello-prefix-umu.tar.xz"
        tar -xf "$HOME/.winellotmp/osu-winello-prefix-umu.tar.xz" -C "$HOME/.local/share/wineprefixes"
        mv "$HOME/.local/share/wineprefixes/osu-umu" "$WINEPREFIX" 2>/dev/null || true
        rm -rf "$HOME/.winellotmp"
    fi

    # 清理并重建 dosdevices，方便 drag & drop
    rm -rf "$WINEPREFIX/dosdevices"
    mkdir -p "$WINEPREFIX/dosdevices"
    ln -s "$WINEPREFIX/drive_c" "$WINEPREFIX/dosdevices/c:"
    ln -s / "$WINEPREFIX/dosdevices/z:"

    # 安装资源管理器修复（文件夹打开方式）
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cp "$SCRIPT_DIR/stuff/folderfixosu" "$HOME/.local/share/osuconfig/folderfixosu"
    chmod +x "$HOME/.local/share/osuconfig/folderfixosu"

    "$UMU_RUN" reg add "HKEY_CLASSES_ROOT\\folder\\shell\\open\\command" /f /ve /t REG_SZ /d "$HOME/.local/share/osuconfig/folderfixosu xdg-open \"%1\"" 2>/dev/null
    "$UMU_RUN" reg delete "HKEY_CLASSES_ROOT\\folder\\shell\\open\\ddeexec" /f 2>/dev/null

    # 安装 Winestreamproxy（Discord RPC）
    if [ ! -d "$WINEPREFIX/drive_c/winestreamproxy" ]; then
        Info "正在安装 Winestreamproxy (Discord 状态显示)……"
        downloadfile "$WINESTREAMPROXY_LINK" "/tmp/winestreamproxy-2.0.3-amd64.tar.gz"
        mkdir -p "/tmp/winestreamproxy"
        tar -xf "/tmp/winestreamproxy-2.0.3-amd64.tar.gz" -C "/tmp/winestreamproxy"
        # 杀掉 wineserver 避免冲突
        "$PROTONPATH/files/bin/wineserver" -k 2>/dev/null
        env WINE="$PROTONPATH/files/bin/wine" bash "/tmp/winestreamproxy/install.sh"
        rm -f "/tmp/winestreamproxy-2.0.3-amd64.tar.gz"
        rm -rf "/tmp/winestreamproxy"
    fi

    # 下载 osu! 安装程序
    Info "正在下载 osu! 安装程序……"
    if [ ! -s "$OSUPATH/osu!.exe" ]; then
        downloadfile "$OSU_INSTALLER_LINK" "$OSUPATH/osu!.exe"
    fi

    Info "安装完成！"
    Info "运行 'osu-wine' 即可启动游戏。"
    Info "注意：如果提示找不到命令，请重新打开终端或执行 'source ~/.bashrc'（根据你的 shell 调整）。"
    exit 0
}

# ---------- 更新 Proton-osu ----------
Update() {
    InitProxy
    if [ -d "$HOME/.local/share/osuconfig/wine-osu" ]; then
        Quit "检测到旧版 wine-osu，无法直接更新；请重新安装 Winello（先卸载再装）"
    fi

    LAST_PROTON_VER=$(cat "$HOME/.local/share/osuconfig/protonverupdate" 2>/dev/null || echo "0")
    if [ "$LAST_PROTON_VER" != "$PROTONVERSION" ]; then
        Info "正在更新 Proton-osu 到 $PROTONVERSION……"
        downloadfile "$PROTONLINK" "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz"
        rm -rf "$HOME/.local/share/osuconfig/proton-osu"
        tar -xf "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz" -C "$HOME/.local/share/osuconfig"
        echo "$PROTONVERSION" > "$HOME/.local/share/osuconfig/protonverupdate"
        rm -f "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz"
        Info "更新完成！"
    else
        Info "Proton-osu 已经是最新版本 ($PROTONVERSION)"
    fi
}

# ---------- 安装 gosumemory ----------
Gosumemory() {
    InitProxy
    if [ ! -d "$HOME/.local/share/osuconfig/gosumemory" ]; then
        Info "正在安装 gosumemory……"
        mkdir -p "$HOME/.local/share/osuconfig/gosumemory"
        downloadfile "$GOSUMEMORY_LINK" "/tmp/gosumemory.zip"
        unzip -d "$HOME/.local/share/osuconfig/gosumemory" -q "/tmp/gosumemory.zip"
        rm "/tmp/gosumemory.zip"
        Info "gosumemory 安装完成"
    else
        Info "gosumemory 已存在，跳过安装"
    fi
}

# ---------- 帮助信息 ----------
Help() {
    cat << EOF
用法: ./osu-winello.sh [命令]

命令:
  (无参数)        - 完整安装 osu!（首次运行）
  uninstall       - 卸载 osu! 及所有相关文件
  update          - 更新 Proton-osu 到最新版
  gosumemory      - 单独安装 gosumemory（内存读取工具）
  help 或 -h      - 显示此帮助

更多信息请访问: https://github.com/NelloKudo/osu-winello
EOF
}

# ---------- 入口 ----------
case "$1" in
    '')
        InitialSetup
        InstallProton
        ConfigurePath
        FullInstall
        ;;
    uninstall)
        Uninstall
        ;;
    update)
        Update
        ;;
    gosumemory)
        Gosumemory
        ;;
    help|-h)
        Help
        ;;
    *)
        Info "未知参数 '$1'，使用 'help' 查看帮助"
        ;;
esac

# 祝你玩得开心！