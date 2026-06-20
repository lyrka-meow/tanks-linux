#!/bin/sh

set -u

APP_NAME="Tanks Blitz Linux"
APP_ID="tanks-blitz-linux"
APP_DIR="$HOME/.local/share/$APP_ID"
BIN_DIR="$HOME/bin"
LOG_DIR="$APP_DIR/logs"
DOWNLOAD_DIR="$APP_DIR/downloads"
PROTON_VERSION="GE-Proton10-34"
PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-34/GE-Proton10-34.tar.gz"
LGC_URL="https://redirect.lesta.ru/LGC/Lesta_Game_Center_Install_RU.exe"
STEAM_COMPAT_APP_ID="450422364"

red="$(printf '\033[31m')"
green="$(printf '\033[32m')"
yellow="$(printf '\033[33m')"
blue="$(printf '\033[34m')"
bold="$(printf '\033[1m')"
reset="$(printf '\033[0m')"

say() {
    printf '%s\n' "$1"
}

ok() {
    printf '%s%s%s\n' "$green" "$1" "$reset"
}

warn() {
    printf '%s%s%s\n' "$yellow" "$1" "$reset"
}

fail() {
    printf '%s%s%s\n' "$red" "$1" "$reset"
}

pause() {
    printf '\nНажмите Enter для продолжения... '
    read _answer
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1
}

ensure_base_dirs() {
    mkdir -p "$APP_DIR" "$BIN_DIR" "$LOG_DIR" "$DOWNLOAD_DIR" "$HOME/.local/share/applications"
}

ensure_path() {
    case ":$PATH:" in
        *":$BIN_DIR:"*) return 0 ;;
    esac

    for file in "$HOME/.profile" "$HOME/.bashrc"; do
        if [ -f "$file" ]; then
            if ! grep -F "export PATH=\"\$HOME/bin:\$PATH\"" "$file" >/dev/null 2>&1; then
                printf '\nexport PATH="$HOME/bin:$PATH"\n' >> "$file"
            fi
        else
            printf 'export PATH="$HOME/bin:$PATH"\n' > "$file"
        fi
    done

    warn "Добавил $BIN_DIR в PATH. Если команда tanks не найдется, перелогиньтесь или выполните: export PATH=\"\$HOME/bin:\$PATH\""
}

detect_downloader() {
    if need_cmd curl; then
        DOWNLOADER="curl"
        return 0
    fi

    if need_cmd wget; then
        DOWNLOADER="wget"
        return 0
    fi

    fail "Нужен curl или wget."
    return 1
}

download_file() {
    url="$1"
    out="$2"

    if [ "${DOWNLOADER:-}" = "curl" ]; then
        curl -L --fail --progress-bar "$url" -o "$out"
        return $?
    fi

    wget -O "$out" "$url"
}

check_tools() {
    missing=""

    for cmd in tar gzip sed grep chmod mkdir rm find cp; do
        if ! need_cmd "$cmd"; then
            missing="$missing $cmd"
        fi
    done

    if ! detect_downloader; then
        return 1
    fi

    if [ -n "$missing" ]; then
        fail "Не найдены команды:$missing"
        return 1
    fi

    return 0
}

ask_prime_run() {
    while :; do
        printf 'Использовать prime-run для NVIDIA? [y/N]: '
        read answer
        case "$answer" in
            y|Y|yes|YES|д|Д|да|Да|ДА)
                if need_cmd prime-run; then
                    PRIME_RUN="prime-run"
                    return 0
                fi
                warn "prime-run не найден. Запуск будет без него."
                PRIME_RUN=""
                return 0
                ;;
            ""|n|N|no|NO|н|Н|нет|Нет|НЕТ)
                PRIME_RUN=""
                return 0
                ;;
            *)
                warn "Введите y или n."
                ;;
        esac
    done
}

write_config() {
    cat > "$APP_DIR/config" <<EOF
PRIME_RUN="$PRIME_RUN"
EOF
}

install_proton() {
    proton_dir="$APP_DIR/proton/$PROTON_VERSION"
    proton_archive="$DOWNLOAD_DIR/$PROTON_VERSION.tar.gz"

    if [ -x "$proton_dir/proton" ]; then
        ok "Proton уже установлен."
        return 0
    fi

    mkdir -p "$APP_DIR/proton"

    if [ ! -f "$proton_archive" ]; then
        say "Скачиваю $PROTON_VERSION..."
        download_file "$PROTON_URL" "$proton_archive" || return 1
    fi

    say "Распаковываю Proton..."
    tar -xzf "$proton_archive" -C "$APP_DIR/proton" || return 1

    if [ ! -x "$proton_dir/proton" ]; then
        fail "Proton не найден после распаковки."
        return 1
    fi

    ok "Proton установлен."
}

download_lgc() {
    installer="$DOWNLOAD_DIR/Lesta_Game_Center_Install_RU.exe"

    if [ -f "$installer" ]; then
        ok "Установщик Lesta Game Center уже скачан."
        return 0
    fi

    say "Скачиваю Lesta Game Center..."
    download_file "$LGC_URL" "$installer"
}

write_launcher() {
    cat > "$BIN_DIR/tanks" <<EOF
#!/bin/sh

APP_DIR="$APP_DIR"
PROTON_VERSION="$PROTON_VERSION"
STEAM_COMPAT_APP_ID="$STEAM_COMPAT_APP_ID"

if [ "\${1:-}" = "menu" ]; then
    exec "\$APP_DIR/installer.sh"
fi

if [ "\${1:-}" = "uninstall" ]; then
    exec "\$APP_DIR/installer.sh" uninstall
fi

if [ -f "\$APP_DIR/config" ]; then
    . "\$APP_DIR/config"
else
    PRIME_RUN=""
fi

PROTON="\$APP_DIR/proton/\$PROTON_VERSION/proton"
COMPAT="\$APP_DIR/compat"
PREFIX="\$COMPAT/pfx"
LGC="\$PREFIX/drive_c/Program Files (x86)/Lesta/GameCenter/lgc.exe"
LOGS="\$APP_DIR/logs"

mkdir -p "\$LOGS" "\$COMPAT"

if [ ! -x "\$PROTON" ]; then
    echo "Proton не найден. Запустите: tanks menu"
    exit 1
fi

if [ ! -f "\$LGC" ]; then
    echo "Lesta Game Center не найден. Запустите: tanks menu"
    exit 1
fi

export STEAM_COMPAT_DATA_PATH="\$COMPAT"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="\$HOME/.local/share/Steam"
export STEAM_COMPAT_APP_ID="\$STEAM_COMPAT_APP_ID"
export PROTON_LOG=1
export PROTON_LOG_DIR="\$LOGS"
export PROTON_USE_WINED3D=1
export WINEDLLOVERRIDES="d3d9,d3d10core,d3d11,dxgi=b"
export GDK_SCALE=1
export QT_SCALE_FACTOR=1
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_PATH="\$APP_DIR/nvidia-cache"

mkdir -p "\$__GL_SHADER_DISK_CACHE_PATH"

cd "\$(dirname "\$LGC")" || exit 1

if [ -n "\$PRIME_RUN" ]; then
    exec \$PRIME_RUN "\$PROTON" run "\$LGC" --disable-gpu --disable-gpu-compositing --disable-gpu-sandbox "\$@" > "\$LOGS/tanks.log" 2>&1
fi

exec "\$PROTON" run "\$LGC" --disable-gpu --disable-gpu-compositing --disable-gpu-sandbox "\$@" > "\$LOGS/tanks.log" 2>&1
EOF

    chmod +x "$BIN_DIR/tanks"
}

write_desktop_file() {
    desktop="$HOME/.local/share/applications/$APP_ID.desktop"

    cat > "$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Tanks Blitz
Comment=Запуск Tanks Blitz через Proton
Exec=$BIN_DIR/tanks
Terminal=false
Categories=Game;
StartupNotify=false
EOF

    chmod +x "$desktop"

    if need_cmd update-desktop-database; then
        update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
    fi
}

clean_shortcuts() {
    find "$HOME/Desktop" "$HOME/Рабочий стол" "$HOME/.local/share/applications" "$APP_DIR/compat/pfx/drive_c/users" "$APP_DIR/compat/pfx/drive_c/proton_shortcuts" -maxdepth 5 \( -iname '*Lesta*.desktop' -o -iname '*Lesta*.lnk' -o -iname '*Tanks_Blitz*.desktop' -o -iname '*Tanks Blitz*.desktop' -o -iname '*Tanks*.lnk' \) -type f 2>/dev/null | while IFS= read -r file; do
        case "$file" in
            "$HOME/.local/share/applications/$APP_ID.desktop") ;;
            *) rm -f "$file" ;;
        esac
    done
}

copy_self() {
    if [ -f "$0" ]; then
        cp "$0" "$APP_DIR/installer.sh" 2>/dev/null || true
    fi

    if [ ! -f "$APP_DIR/installer.sh" ]; then
        if [ "${DOWNLOADER:-}" = "curl" ]; then
            curl -fsSL "https://raw.githubusercontent.com/lyrka-meow/tanks-linux/main/installer.sh" -o "$APP_DIR/installer.sh" 2>/dev/null || true
        elif [ "${DOWNLOADER:-}" = "wget" ]; then
            wget -qO "$APP_DIR/installer.sh" "https://raw.githubusercontent.com/lyrka-meow/tanks-linux/main/installer.sh" 2>/dev/null || true
        fi
    fi

    if [ -f "$APP_DIR/installer.sh" ]; then
        chmod +x "$APP_DIR/installer.sh"
    fi
}

run_lgc_installer() {
    installer="$DOWNLOAD_DIR/Lesta_Game_Center_Install_RU.exe"
    proton="$APP_DIR/proton/$PROTON_VERSION/proton"
    compat="$APP_DIR/compat"

    export STEAM_COMPAT_DATA_PATH="$compat"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"
    export STEAM_COMPAT_APP_ID="$STEAM_COMPAT_APP_ID"
    export PROTON_LOG=1
    export PROTON_LOG_DIR="$LOG_DIR"
    export PROTON_USE_WINED3D=1
    export WINEDLLOVERRIDES="d3d9,d3d10core,d3d11,dxgi=b"
    export GDK_SCALE=1
    export QT_SCALE_FACTOR=1
    export QT_AUTO_SCREEN_SCALE_FACTOR=0

    mkdir -p "$compat"

    say "Запускаю установщик Lesta Game Center."
    say "После установки установите Tanks Blitz внутри лаунчера."

    if [ -n "$PRIME_RUN" ]; then
        "$PRIME_RUN" "$proton" run "$installer"
    else
        "$proton" run "$installer"
    fi
}

install_all() {
    ensure_base_dirs
    check_tools || return 1
    ask_prime_run
    write_config
    install_proton || return 1
    download_lgc || return 1
    write_launcher
    write_desktop_file
    clean_shortcuts
    copy_self
    ensure_path
    run_lgc_installer || return 1
    clean_shortcuts
    ok "Готово. Запуск: tanks"
}

uninstall_all() {
    warn "Будет удалено: $APP_DIR, $BIN_DIR/tanks, ярлык $APP_ID.desktop"
    printf 'Продолжить? [y/N]: '
    read answer

    case "$answer" in
        y|Y|yes|YES|д|Д|да|Да|ДА) ;;
        *) return 0 ;;
    esac

    rm -rf "$APP_DIR"
    rm -f "$BIN_DIR/tanks"
    rm -f "$HOME/.local/share/applications/$APP_ID.desktop"
    clean_shortcuts
    ok "Удалено."
}

show_status() {
    say "${bold}$APP_NAME${reset}"
    say "Папка: $APP_DIR"

    if [ -x "$BIN_DIR/tanks" ]; then
        ok "Команда tanks установлена."
    else
        warn "Команда tanks не установлена."
    fi

    if [ -x "$APP_DIR/proton/$PROTON_VERSION/proton" ]; then
        ok "Proton установлен."
    else
        warn "Proton не установлен."
    fi

    if [ -f "$APP_DIR/compat/pfx/drive_c/Program Files (x86)/Lesta/GameCenter/lgc.exe" ]; then
        ok "Lesta Game Center найден."
    else
        warn "Lesta Game Center не найден."
    fi

    if [ -f "$APP_DIR/config" ]; then
        . "$APP_DIR/config"
        if [ -n "$PRIME_RUN" ]; then
            say "prime-run: включен"
        else
            say "prime-run: выключен"
        fi
    fi
}

menu() {
    while :; do
        clear 2>/dev/null || true
        say "${blue}${bold}$APP_NAME${reset}"
        say ""
        say "1. Установить Lesta Game Center"
        say "2. Запустить Tanks Blitz"
        say "3. Показать статус"
        say "4. Удалить Tanks Blitz и настройки"
        say "5. Убрать лишние ярлыки Lesta"
        say "0. Выход"
        say ""
        printf 'Выбор: '
        read choice

        case "$choice" in
            1) install_all; pause ;;
            2) "$BIN_DIR/tanks"; pause ;;
            3) show_status; pause ;;
            4) uninstall_all; pause ;;
            5) clean_shortcuts; ok "Лишние ярлыки удалены."; pause ;;
            0) exit 0 ;;
            *) warn "Нет такого пункта."; pause ;;
        esac
    done
}

if [ "${1:-}" = "uninstall" ]; then
    uninstall_all
    exit $?
fi

menu
