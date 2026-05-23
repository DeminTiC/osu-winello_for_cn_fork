#!/usr/bin/env bash

#   =======================================
#   欢迎使用 Winello！
#   整个脚本被分为不同的函数以便阅读。
#   欢迎贡献代码！
#   =======================================

# =========================================
#   所有外部下载地址（集中在此维护）
# =========================================

# Proton-osu 相关
PROTONVERSION=9.16
LASTPROTONVERSION=0
PROTONLINK="https://github.com/whrvt/umubuilder/releases/download/proton-osu-9-16/proton-osu-9-16.tar.xz"

# Wine 容器（预配置前缀）
PREFIXLINK="https://github.com/DeminTiC/TOPiC-s-Asset-Dictionary/raw/refs/heads/main/Proton-osu/osu-winello-prefix.tar.xz"

# osu!mime 和 osu-handler
OSU_MIME_LINK="https://aur.archlinux.org/cgit/aur.git/snapshot/osu-mime.tar.gz"
OSU_HANDLER_LINK="https://github.com/NelloKudo/osu-winello/raw/main/stuff/osu-handler-wine"

# Winestreamproxy（Discord RPC）
WINESTREAMPROXY_LINK="https://github.com/openglfreak/winestreamproxy/releases/download/v2.0.3/winestreamproxy-2.0.3-amd64.tar.gz"

# osu! 安装程序
OSU_INSTALLER_LINK="http://m1.ppy.sh/r/osu!install.exe"

# gosumemory（内存读取工具）
GOSUMEMORY_LINK="https://github.com/l3lackShark/gosumemory/releases/download/1.3.9/gosumemory_windows_amd64.zip"

# 代理配置文件
PROXY_CONFIG="$HOME/.local/share/osuconfig/proxy.conf"
GITHUB_PROXY=""          # 全局变量，存储代理前缀（空表示不使用）

# =========================================
#   代理初始化函数（询问用户并保存配置）
# =========================================

function InitProxy() {
    # 如果已经设置过全局变量，直接返回
    [ -n "$GITHUB_PROXY_SET" ] && return
    # 检查配置文件是否存在
    if [ -f "$PROXY_CONFIG" ]; then
        GITHUB_PROXY=$(cat "$PROXY_CONFIG")
        GITHUB_PROXY_SET=1
        return
    fi

    # 首次运行，询问用户
    echo -e '\033[1;33mWinello: 你是否希望为 GitHub 下载启用 CDN 加速（国内用户推荐）？\033[0m'
    read -r -p "启用代理? (y/N): " proxy_choice
    if [[ "$proxy_choice" =~ ^[Yy]$ ]]; then
        # 默认使用 ghproxy.com，你也可以让用户自定义镜像地址
        GITHUB_PROXY="https://ghproxy.com/"
        echo -e '\033[1;32m已启用 GitHub 代理：'"$GITHUB_PROXY"\033[0m
    else
        GITHUB_PROXY=""
        echo -e '\033[1;32m将直接连接 GitHub（不使用代理）\033[0m'
    fi
    # 保存到配置文件
    mkdir -p "$(dirname "$PROXY_CONFIG")"
    echo "$GITHUB_PROXY" > "$PROXY_CONFIG"
    GITHUB_PROXY_SET=1
}

# =========================================
#   通用下载函数（封装 wget + 代理支持）
# =========================================

function downloadfile() {
    local url="$1"
    local output="$2"
    local retry=0
    local max_retries=2

    # 如果启用了代理且 URL 是 GitHub 相关，则添加代理前缀
    if [ -n "$GITHUB_PROXY" ]; then
        if [[ "$url" =~ github\.com ]] || [[ "$url" =~ raw\.githubusercontent\.com ]]; then
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
    Error "下载失败（多次尝试后）: $url"
}

# =========================================
#   基础函数：输出、退出、回滚
# =========================================

function Info(){
    echo -e '\033[1;34m'"Winello:\033[0m $*";
}

function Quit(){
    echo -e '\033[1;31m'"Winello:\033[0m $*"; exit 1;
}

function Revert(){
    echo -e '\033[1;31m'"正在回滚安装...:\033[0m"
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
    echo -e '\033[1;31m'"回滚完成，请重新运行 ./osu-winello.sh\033[0m"
}

function Error(){
    echo -e '\033[1;31m'"脚本失败:\033[0m $*"; Revert ; exit 1;
}

# =========================================
#   安装前的环境检查和准备
# =========================================

function InitialSetup(){
    if [ "$USER" = "root" ] ; then Error "请不要使用 root 用户运行脚本" ; fi

    if [ -e /usr/bin/osu-wine ] ; then Quit "请先卸载旧版 osu-wine (/usr/bin/osu-wine) 再安装！"; fi
    if [ -e "$HOME/.local/bin/osu-wine" ] ; then Quit "请先卸载 Winello（osu-wine --remove）再安装！"; fi

    Info "欢迎使用本脚本！跟着提示安装 osu! 8)"

    root_var="sudo"
    if command -v doas >/dev/null 2>&1 ; then
        doascheck=$(doas id -u)
        if [ "$doascheck" = "0" ] ; then 
            root_var="doas"
        fi
    fi

    mkdir -p "/home/$USER/.local/bin"
    pathcheck=$(echo "$PATH" | grep -q "/home/$USER/.local/bin" && echo "y")

    if [ "$pathcheck" != "y" ] ; then
        if grep -q "bash" "$SHELL" ; then
            touch -a "/home/$USER/.bashrc"
            echo "export PATH=/home/$USER/.local/bin:$PATH" >> "/home/$USER/.bashrc"
        fi
        if grep -q "zsh" "$SHELL" ; then
            touch -a "/home/$USER/.zshrc"
            echo "export PATH=/home/$USER/.local/bin:$PATH" >> "/home/$USER/.zshrc"
        fi
        if grep -q "fish" "$SHELL" ; then
            mkdir -p "/home/$USER/.config/fish" && touch -a "/home/$USER/.config/fish/config.fish"
            fish_add_path ~/.local/bin/
        fi
    fi

    Info "正在检查网络连接.."
    ! ping -c 1 114.114.114.114 >/dev/null 2>&1 && ! ping -c 1 bing.com >/dev/null 2>&1 && Error "请连接互联网后再继续 xd。重新运行脚本"

    deps=(wget zenity)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1 ; then
            Error "请先安装 $dep 再继续！"
        fi
    done

    if ! command -v update-mime-database >/dev/null 2>&1 ; then
        Error "请先安装 update-mime-database（通常属于 shared-mime-info 软件包）"
    fi

    # 初始化代理配置（首次使用会询问）
    InitProxy
}

# =========================================
#   安装 Proton-osu、umu-run 和启动脚本
# =========================================

function InstallProton(){
    Info "正在安装游戏脚本："
    cp ./osu-wine "$HOME/.local/bin/osu-wine" && chmod +x "$HOME/.local/bin/osu-wine"

    Info "正在安装图标："
    mkdir -p "$HOME/.local/share/icons"    
    cp "./stuff/osu-wine.png" "$HOME/.local/share/icons/osu-wine.png" && chmod 644 "$HOME/.local/share/icons/osu-wine.png"

    Info "正在安装 .desktop 文件："
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/osu-wine.desktop" << EOF
[Desktop Entry]
Name=osu!
Comment=osu! - 节奏只需 *点击* 一下！
Type=Application
Exec=/home/$USER/.local/bin/osu-wine %U
Icon=/home/$USER/.local/share/icons/osu-wine.png
Terminal=false
Categories=Wine;Game;
EOF
    chmod +x "$HOME/.local/share/applications/osu-wine.desktop"

    if [ ! -d "$HOME/.local/share/osuconfig" ]; then
        mkdir "$HOME/.local/share/osuconfig"
    else
        Info "跳过 osuconfig.."
    fi

    Info "正在安装 Proton-osu："
    downloadfile "$PROTONLINK" "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz"
    tar -xf "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz" -C "$HOME/.local/share/osuconfig"
    LASTPROTONVERSION="$PROTONVERSION"
    rm -f "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz"

    Info "正在安装脚本副本以支持更新.."
    mkdir -p "$HOME/.local/share/osuconfig/update"
    # 根据是否启用代理，选择 git clone 或 zip 下载
    if [ -n "$GITHUB_PROXY" ]; then
        Info "使用代理下载脚本仓库（zip 包）"
        downloadfile "https://github.com/NelloKudo/osu-winello/archive/refs/heads/main.zip" "/tmp/osu-winello-main.zip"
        unzip -q "/tmp/osu-winello-main.zip" -d "/tmp"
        mv "/tmp/osu-winello-main" "$HOME/.local/share/osuconfig/update"
        rm -f "/tmp/osu-winello-main.zip"
    else
        git clone https://github.com/NelloKudo/osu-winello.git "$HOME/.local/share/osuconfig/update" || Error "Git 失败，请检查网络连接.."
    fi
    echo "$LASTPROTONVERSION" > "$HOME/.local/share/osuconfig/protonverupdate"

    Info "正在安装 umu-launcher.."
    cp ./stuff/umu-run "$HOME/.local/share/osuconfig"
    chmod +x "$HOME/.local/share/osuconfig/umu-run"
    UMU_RUN="$HOME/.local/share/osuconfig/umu-run"
    export GAMEID="osu-wine-umu"
}

# =========================================
#   选择游戏安装目录（保持不变）
# =========================================

function ConfigurePath(){
    # ... 完全保持原样，此处省略以节省篇幅 ...
    # 实际使用时请复制原脚本中的完整函数内容
}

# =========================================
#   完整安装（MIME、Wine 前缀、Discord RPC 等）
# =========================================

function FullInstall(){
    # 确保代理已初始化
    InitProxy

    Info "正在配置 osu-mime 和 osu-handler："

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

    # 创建文件关联的 desktop 条目（不变）
    # ... 省略相同部分 ...

    # 配置 Wine 容器（部分代码不变，仅保持调用 downloadfile）
    # ... 省略相同部分 ...

    # 安装 Winestreamproxy
    if [ ! -d "$HOME/.local/share/wineprefixes/osu-wineprefix/drive_c/winestreamproxy" ] ; then
        Info "正在配置 Winestreamproxy（Discord RPC）"
        downloadfile "$WINESTREAMPROXY_LINK" "/tmp/winestreamproxy-2.0.3-amd64.tar.gz"
        # ... 后续解压安装不变 ...
    fi

    # 下载 osu! 安装程序
    Info "正在下载 osu!"
    if [ ! -s "$OSUPATH/osu!.exe" ]; then
        downloadfile "$OSU_INSTALLER_LINK" "$OSUPATH/osu!.exe"
    fi

    Info "安装完成！运行 'osu-wine' 即可游玩 osu!"
    Info "警告：如果 'osu-wine' 无法运行，只需关闭并重新打开终端。"
    exit 0
}

# =========================================
#   更新 Proton-osu（加入代理初始化）
# =========================================

function Update(){
    InitProxy   # 确保代理配置已加载

    if [ -d "$HOME/.local/share/osuconfig/wine-osu" ]; then
        Quit "检测到 wine-osu 且已是最新；如果要使用 proton-osu，请重新安装 Winello！"
    fi

    LASTPROTONVERSION=$(cat "$HOME/.local/share/osuconfig/protonverupdate" 2>/dev/null)
    if [ -z "$LASTPROTONVERSION" ]; then
        LASTPROTONVERSION=0
    fi

    if [ "$LASTPROTONVERSION" != "$PROTONVERSION" ]; then
        downloadfile "$PROTONLINK" "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz"
        Info "正在更新 Proton-osu..."
        rm -rf "$HOME/.local/share/osuconfig/proton-osu"
        tar -xf "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz" -C "$HOME/.local/share/osuconfig"
        rm -f "/tmp/proton-osu-${PROTONVERSION}-x86_64.pkg.tar.xz"
        echo "$PROTONVERSION" > "$HOME/.local/share/osuconfig/protonverupdate"
        Info "更新完成！"
    else
        Info "你的 Proton-osu 已经是最新！"
    fi
}

# =========================================
#   下载 gosumemory（加入代理初始化）
# =========================================

function Gosumemory(){
    InitProxy
    if [ ! -d "$HOME/.local/share/osuconfig/gosumemory" ]; then
        Info "正在安装 gosumemory.."
        mkdir -p "$HOME/.local/share/osuconfig/gosumemory"
        downloadfile "$GOSUMEMORY_LINK" "/tmp/gosumemory.zip"
        unzip -d "$HOME/.local/share/osuconfig/gosumemory" -q "/tmp/gosumemory.zip"
        rm "/tmp/gosumemory.zip"
    fi
}

# =========================================
#   帮助信息与主入口（不变）
# =========================================

function Help(){
    Info "安装游戏：运行 ./osu-winello.sh
          卸载游戏：运行 ./osu-winello.sh uninstall
          更多信息请阅读 README.md 或访问 https://github.com/NelloKudo/osu-winello"
}

case "$1" in
    '')
        InitialSetup
        InstallProton
        ConfigurePath
        FullInstall
        ;;
    'uninstall')
        Uninstall
        ;;
    'gosumemory')
        Gosumemory
        ;;
    'update')
        Update
        ;;
    'help'|'-h')
        Help
        ;;
    *)
        Info "未知参数，请使用 ./osu-winello.sh help 或 ./osu-winello.sh -h"
        ;;
esac

# 感谢你读完全文！祝玩 osu! 开心！