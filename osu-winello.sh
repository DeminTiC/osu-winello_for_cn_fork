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
PREFIXLINK="https://gitlab.com/NelloKudo/osu-winello-prefix/-/raw/master/osu-winello-prefix-umu.tar.xz"

# osu!mime 和 osu-handler
OSU_MIME_LINK="https://aur.archlinux.org/cgit/aur.git/snapshot/osu-mime.tar.gz"
OSU_HANDLER_LINK="https://github.com/NelloKudo/osu-winello/raw/main/stuff/osu-handler-wine"

# Winestreamproxy（Discord RPC）
WINESTREAMPROXY_LINK="https://github.com/openglfreak/winestreamproxy/releases/download/v2.0.3/winestreamproxy-2.0.3-amd64.tar.gz"

# osu! 安装程序
OSU_INSTALLER_LINK="http://m1.ppy.sh/r/osu!install.exe"

# gosumemory（内存读取工具）
GOSUMEMORY_LINK="https://github.com/l3lackShark/gosumemory/releases/download/1.3.9/gosumemory_windows_amd64.zip"

# =========================================
#   通用下载函数（封装 wget 与重试逻辑）
# =========================================

function downloadfile() {
    local url="$1"
    local output="$2"
    local retry=0
    local max_retries=2

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
    git clone https://github.com/NelloKudo/osu-winello.git "$HOME/.local/share/osuconfig/update" || Error "Git 失败，请检查网络连接.."
    echo "$LASTPROTONVERSION" > "$HOME/.local/share/osuconfig/protonverupdate"

    Info "正在安装 umu-launcher.."
    cp ./stuff/umu-run "$HOME/.local/share/osuconfig"
    chmod +x "$HOME/.local/share/osuconfig/umu-run"
    UMU_RUN="$HOME/.local/share/osuconfig/umu-run"
    export GAMEID="osu-wine-umu"
}

# =========================================
#   选择游戏安装目录
# =========================================

function ConfigurePath(){
    Info "正在配置 osu! 文件夹："
    Info "你想把游戏安装在哪里？: 
          1 - 默认路径 (~/.local/share/osu-wine)
          2 - 自定义路径"
    read -r -p "$(Info "请选择选项：")" installpath
    
    if [ "$installpath" = 1 ] || [ "$installpath" = 2 ] ; then  
        case "$installpath" in
        '1')  
            mkdir -p "$HOME/.local/share/osu-wine"
            GAMEDIR="$HOME/.local/share/osu-wine"
            if [ -d "$GAMEDIR/OSU" ]; then
                OSUPATH="$GAMEDIR/OSU"
            else
                mkdir -p "$GAMEDIR/osu!"
                OSUPATH="$GAMEDIR/osu!"
            fi
            ;;
        '2')
            Info "请选择你的目录："
            GAMEDIR="$(zenity --file-selection --directory)"
            if [ -e "$GAMEDIR/osu!.exe" ]; then
                OSUPATH="$GAMEDIR"
            else
                mkdir -p "$GAMEDIR/osu!"
                OSUPATH="$GAMEDIR/osu!"
            fi
            ;;
        esac
    else
        Info "未选择选项，安装到默认位置.. (~/.local/share/osu-wine)"
        mkdir -p "$HOME/.local/share/osu-wine"
        GAMEDIR="$HOME/.local/share/osu-wine"
        if [ -d "$GAMEDIR/OSU" ]; then
            OSUPATH="$GAMEDIR/OSU"
        else
            mkdir -p "$GAMEDIR/osu!"
            OSUPATH="$GAMEDIR/osu!"
        fi
    fi

    echo "$OSUPATH" > "$HOME/.local/share/osuconfig/osupath"
}

# =========================================
#   完整安装（MIME、Wine 前缀、Discord RPC 等）
# =========================================

function FullInstall(){
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

    # 创建文件关联的 desktop 条目
    cat > "$HOME/.local/share/applications/osuwinello-file-extensions-handler.desktop" << EOF
[Desktop Entry]
Type=Application
Name=osu!
MimeType=application/x-osu-skin-archive;application/x-osu-replay;application/x-osu-beatmap-archive;
Exec=/home/$USER/.local/share/osuconfig/osu-handler-wine %f
NoDisplay=true
StartupNotify=true
Icon=/home/$USER/.local/share/icons/osu-wine.png
EOF
    chmod +x "$HOME/.local/share/applications/osuwinello-file-extensions-handler.desktop"

    cat > "$HOME/.local/share/applications/osuwinello-url-handler.desktop" << EOF
[Desktop Entry]
Type=Application
Name=osu!
MimeType=x-scheme-handler/osu;
Exec=/home/$USER/.local/share/osuconfig/osu-handler-wine %u
NoDisplay=true
StartupNotify=true
Icon=/home/$USER/.local/share/icons/osu-wine.png
EOF
    chmod +x "$HOME/.local/share/applications/osuwinello-url-handler.desktop"
    update-desktop-database "$HOME/.local/share/applications"

    # 配置 Wine 容器
    export PROTONPATH="$HOME/.local/share/osuconfig/proton-osu"
    Info "正在配置 Wine 容器："

    failprefix="false"
    mkdir -p "$HOME/.local/share/wineprefixes"
    if [ -d "$HOME/.local/share/wineprefixes/osu-wineprefix" ] ; then
        Info "Wine 容器已存在，是否重新安装？"
        read -r -p "$(Info "请选择： (y/N)")" prefchoice
        if [ "$prefchoice" = 'y' ] || [ "$prefchoice" = 'Y' ]; then
            rm -rf "$HOME/.local/share/wineprefixes/osu-wineprefix"
        fi
    fi

    if [ ! -d "$HOME/.local/share/wineprefixes/osu-wineprefix" ] ; then
        mkdir -p "$HOME/.winellotmp"
        # 尝试下载预配置前缀，失败则标记为手动创建
        if ! downloadfile "$PREFIXLINK" "$HOME/.winellotmp/osu-winello-prefix-umu.tar.xz" 2>/dev/null; then
            failprefix="true"
        fi

        if [ "$failprefix" = "true" ]; then
            WINEPREFIX="$HOME/.local/share/wineprefixes/osu-wineprefix" "$UMU_RUN" winetricks dotnet20 dotnet48 gdiplus_winxp win2k3
        else
            tar -xf "$HOME/.winellotmp/osu-winello-prefix-umu.tar.xz" -C "$HOME/.local/share/wineprefixes"
            mv "$HOME/.local/share/wineprefixes/osu-umu" "$HOME/.local/share/wineprefixes/osu-wineprefix" 
        fi

        export WINEPREFIX="$HOME/.local/share/wineprefixes/osu-wineprefix"

        rm -rf "$WINEPREFIX/dosdevices"
        rm -rf "$WINEPREFIX/drive_c/users/nellokudo"
        mkdir -p "$WINEPREFIX/dosdevices"
        ln -s "$WINEPREFIX/drive_c/" "$WINEPREFIX/dosdevices/c:"
        ln -s / "$WINEPREFIX/dosdevices/z:"

        cp "./stuff/folderfixosu" "$HOME/.local/share/osuconfig/folderfixosu" && chmod +x "$HOME/.local/share/osuconfig/folderfixosu"
        "$UMU_RUN" reg add "HKEY_CLASSES_ROOT\folder\shell\open\command"
        "$UMU_RUN" reg delete "HKEY_CLASSES_ROOT\folder\shell\open\ddeexec" /f
        "$UMU_RUN" reg add "HKEY_CLASSES_ROOT\folder\shell\open\command" /f /ve /t REG_SZ /d "/home/$USER/.local/share/osuconfig/folderfixosu xdg-open \"%1\""
    fi

    # 安装 Winestreamproxy (Discord RPC)
    if [ ! -d "$HOME/.local/share/wineprefixes/osu-wineprefix/drive_c/winestreamproxy" ] ; then
        Info "正在配置 Winestreamproxy（Discord RPC）"
        downloadfile "$WINESTREAMPROXY_LINK" "/tmp/winestreamproxy-2.0.3-amd64.tar.gz"
        mkdir -p "/tmp/winestreamproxy"
        tar -xf "/tmp/winestreamproxy-2.0.3-amd64.tar.gz" -C "/tmp/winestreamproxy"
        WINESERVER_PATH="$PROTONPATH/files/bin/wineserver"
        WINE_PATH="$PROTONPATH/files/bin/wine"
        $WINESERVER_PATH -k && WINE=$WINE_PATH bash "/tmp/winestreamproxy/install.sh"
        rm -f "/tmp/winestreamproxy-2.0.3-amd64.tar.gz"
        rm -rf "/tmp/winestreamproxy"
    fi

    rm -rf "$HOME/.winellotmp"

    Info "正在下载 osu!"
    if [ -s "$OSUPATH/osu!.exe" ]; then
        Info "安装完成！运行 'osu-wine' 即可游玩 osu!"
        Info "警告：如果 'osu-wine' 无法运行，只需关闭并重新打开终端。"
        exit 0
    else
        downloadfile "$OSU_INSTALLER_LINK" "$OSUPATH/osu!.exe"
        Info "安装完成！运行 'osu-wine' 即可游玩 osu!"
        Info "警告：如果 'osu-wine' 无法运行，只需关闭并重新打开终端。"
        exit 0
    fi
}

# =========================================
#   更新 Proton-osu
# =========================================

function Update(){
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
#   卸载游戏
# =========================================

function Uninstall(){
    Info "正在卸载图标："
    rm -f "$HOME/.local/share/icons/osu-wine.png"
    
    Info "正在卸载 .desktop 文件："
    rm -f "$HOME/.local/share/applications/osu-wine.desktop"
    
    Info "正在卸载游戏脚本、工具和 folderfix："
    rm -f "$HOME/.local/bin/osu-wine"
    rm -f "$HOME/.local/bin/folderfixosu"
    rm -f "$HOME/.local/share/mime/packages/osuwinello-file-extensions.xml"
    rm -f "$HOME/.local/share/applications/osuwinello-file-extensions-handler.desktop"
    rm -f "$HOME/.local/share/applications/osuwinello-url-handler.desktop"

    Info "正在卸载 proton-osu："
    rm -rf "$HOME/.local/share/osuconfig/proton-osu"
    
    read -r -p "$(Info "是否要卸载 Wine 容器？ (y/n)")" wineprch
    if [ "$wineprch" = 'y' ] || [ "$wineprch" = 'Y' ]; then
        rm -rf "$HOME/.local/share/wineprefixes/osu-wineprefix"
    else
        Info "跳过.."
    fi

    read -r -p "$(Info "是否要卸载游戏文件？ (y/n)")" choice
    if [ "$choice" = 'y' ] || [ "$choice" = 'Y' ]; then
        read -r -p "$(Info "你确定吗？这将删除你的文件！ (y/n)")" choice2
        if [ "$choice2" = 'y' ] || [ "$choice2" = 'Y' ]; then
            Info "正在卸载游戏："
            if [ -e "$HOME/.local/share/osuconfig/osupath" ]; then
                OSUUNINSTALLPATH=$(cat "$HOME/.local/share/osuconfig/osupath")
                rm -rf "$OSUUNINSTALLPATH"
                rm -rf "$HOME/.local/share/osuconfig"
            else
                rm -rf "$HOME/.local/share/osuconfig"
            fi
        else
            rm -rf "$HOME/.local/share/osuconfig"
            Info "退出.."
        fi
    else
        rm -rf "$HOME/.local/share/osuconfig"
    fi
    
    rm -rf "$HOME/.winellotmp"
    Info "卸载完成！"
}

# =========================================
#   下载 gosumemory
# =========================================

function Gosumemory(){
    if [ ! -d "$HOME/.local/share/osuconfig/gosumemory" ]; then
        Info "正在安装 gosumemory.."
        mkdir -p "$HOME/.local/share/osuconfig/gosumemory"
        downloadfile "$GOSUMEMORY_LINK" "/tmp/gosumemory.zip"
        unzip -d "$HOME/.local/share/osuconfig/gosumemory" -q "/tmp/gosumemory.zip"
        rm "/tmp/gosumemory.zip"
    fi
}

# =========================================
#   帮助信息
# =========================================

function Help(){
    Info "安装游戏：运行 ./osu-winello.sh
          卸载游戏：运行 ./osu-winello.sh uninstall
          更多信息请阅读 README.md 或访问 https://github.com/NelloKudo/osu-winello"
}

# =========================================
#   主入口
# =========================================

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
# （如果你想改进脚本，随时欢迎 PR :3）