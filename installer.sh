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
LGC_PACKAGE_URL="https://redirect.lesta.ru/lds/lesta_game_center_install_ru.dspkg"
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

    warn "Добавил $BIN_DIR в PATH."
    warn "Для текущего терминала выполните: export PATH=\"\$HOME/bin:\$PATH\""
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

detect_extractor() {
    if need_cmd bsdtar; then
        EXTRACTOR="bsdtar"
        return 0
    fi

    if need_cmd 7z; then
        EXTRACTOR="7z"
        return 0
    fi

    if need_cmd 7za; then
        EXTRACTOR="7za"
        return 0
    fi

    if need_cmd 7zr; then
        EXTRACTOR="7zr"
        return 0
    fi

    fail "Нужен bsdtar или 7z для распаковки Lesta Game Center."
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

run_root() {
    if [ "$(id -u)" = "0" ]; then
        "$@"
        return $?
    fi

    if need_cmd sudo; then
        sudo "$@"
        return $?
    fi

    fail "Нужен sudo для установки системных зависимостей."
    return 1
}

install_system_deps() {
    say "Проверяю системные зависимости."

    if need_cmd pacman; then
        packages="curl wget tar gzip sed grep findutils coreutils desktop-file-utils libarchive freetype2 fontconfig libx11 libxrandr libxrender libxi libxinerama libxcursor alsa-lib libpulse openal mesa lib32-freetype2 lib32-fontconfig lib32-mesa"
        if [ -n "${PRIME_RUN:-}" ]; then
            packages="$packages nvidia-prime lib32-nvidia-utils"
        fi
        run_root pacman -S --needed --noconfirm $packages
        return $?
    fi

    if need_cmd apt-get; then
        run_root dpkg --add-architecture i386 >/dev/null 2>&1 || true
        run_root apt-get update || return 1
        packages="curl wget tar gzip sed grep findutils coreutils desktop-file-utils libarchive-tools libfreetype6 fontconfig libgl1 libgl1-mesa-dri libasound2 libpulse0 libopenal1 libx11-6 libxrandr2 libxrender1 libxi6 libxinerama1 libxcursor1 libfreetype6:i386 libfontconfig1:i386 libgl1:i386 libgl1-mesa-dri:i386 libpulse0:i386 libopenal1:i386 libx11-6:i386 libxrandr2:i386 libxrender1:i386 libxi6:i386 libxinerama1:i386 libxcursor1:i386"
        run_root apt-get install -y $packages
        return $?
    fi

    if need_cmd dnf; then
        packages="curl wget tar gzip sed grep findutils coreutils desktop-file-utils bsdtar freetype fontconfig mesa-libGL mesa-dri-drivers alsa-lib pulseaudio-libs openal-soft libX11 libXrandr libXrender libXi libXinerama libXcursor freetype.i686 fontconfig.i686 mesa-libGL.i686 mesa-dri-drivers.i686 alsa-lib.i686 pulseaudio-libs.i686 openal-soft.i686 libX11.i686 libXrandr.i686 libXrender.i686 libXi.i686 libXinerama.i686 libXcursor.i686"
        run_root dnf install -y $packages
        return $?
    fi

    if need_cmd zypper; then
        packages="curl wget tar gzip sed grep findutils coreutils desktop-file-utils bsdtar freetype2 fontconfig Mesa libX11-6 libXrandr2 libXrender1 libXi6 libXinerama1 libXcursor1 libasound2 libpulse0 libopenal1 freetype2-32bit fontconfig-32bit Mesa-32bit libX11-6-32bit libXrandr2-32bit libXrender1-32bit libXi6-32bit libXinerama1-32bit libXcursor1-32bit libasound2-32bit libpulse0-32bit libopenal1-32bit"
        run_root zypper --non-interactive install $packages
        return $?
    fi

    warn "Не найден поддерживаемый менеджер пакетов. Поддерживаются pacman, apt, dnf, zypper."
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
    installer="$DOWNLOAD_DIR/lesta_game_center_install_ru.dspkg"

    if [ -f "$installer" ]; then
        ok "Пакет Lesta Game Center уже скачан."
        return 0
    fi

    say "Скачиваю Lesta Game Center..."
    download_file "$LGC_PACKAGE_URL" "$installer"
}

find_lgc() {
    prefix="$APP_DIR/compat/pfx"

    for file in \
        "$prefix/drive_c/Program Files (x86)/Lesta/GameCenter/lgc.exe" \
        "$prefix/drive_c/Program Files/Lesta/GameCenter/lgc.exe" \
        "$prefix/drive_c/users/steamuser/AppData/Local/Lesta/GameCenter/lgc.exe"
    do
        if [ -f "$file" ]; then
            printf '%s\n' "$file"
            return 0
        fi
    done

    return 1
}

verify_lgc_installed() {
    if find_lgc >/dev/null 2>&1; then
        ok "Lesta Game Center установлен."
        return 0
    fi

    fail "Lesta Game Center не найден после установки."
    warn "Установщик мог быть закрыт, завершиться без установки или поставить файлы в другой путь."
    warn "Запустите установку еще раз через: tanks menu"
    return 1
}

random_hex() {
    od -An -N20 -tx1 /dev/urandom | tr -d ' \n' | tr '[:lower:]' '[:upper:]'
}

write_lgc_data() {
    data="$APP_DIR/compat/pfx/drive_c/ProgramData/Lesta/GameCenter/data"

    mkdir -p "$data"

    if [ ! -f "$data/pc_id.dat" ]; then
        random_hex > "$data/pc_id.dat"
    fi

    if [ ! -f "$data/lgc_id.dat" ]; then
        random_hex > "$data/lgc_id.dat"
    fi

    printf 'C:\\Program Files (x86)\\Lesta\\GameCenter' > "$data/lgc_path.dat"
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
LOGS="\$APP_DIR/logs"

find_lgc() {
    for file in \\
        "\$PREFIX/drive_c/Program Files (x86)/Lesta/GameCenter/lgc.exe" \\
        "\$PREFIX/drive_c/Program Files/Lesta/GameCenter/lgc.exe" \\
        "\$PREFIX/drive_c/users/steamuser/AppData/Local/Lesta/GameCenter/lgc.exe"
    do
        if [ -f "\$file" ]; then
            printf '%s\\n' "\$file"
            return 0
        fi
    done

    return 1
}

mkdir -p "\$LOGS" "\$COMPAT"

if [ ! -x "\$PROTON" ]; then
    echo "Proton не найден. Запустите: tanks menu"
    exit 1
fi

LGC="\$(find_lgc || true)"

if [ -z "\$LGC" ]; then
    echo "Lesta Game Center не найден. Запустите: tanks menu"
    exit 1
fi

export STEAM_COMPAT_DATA_PATH="\$COMPAT"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="\$APP_DIR/steam"
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

mkdir -p "\$__GL_SHADER_DISK_CACHE_PATH" "\$STEAM_COMPAT_CLIENT_INSTALL_PATH"

cd "\$(dirname "\$LGC")" || exit 1

if [ -n "\$PRIME_RUN" ]; then
    exec \$PRIME_RUN "\$PROTON" run "\$LGC" --disable-gpu --disable-gpu-compositing --disable-gpu-sandbox "\$@" > "\$LOGS/tanks.log" 2>&1
fi

exec "\$PROTON" run "\$LGC" --disable-gpu --disable-gpu-compositing --disable-gpu-sandbox "\$@" > "\$LOGS/tanks.log" 2>&1
EOF

    chmod +x "$BIN_DIR/tanks"
}

write_icon_file() {
    icon="$APP_DIR/tanks.svg"

    cat > "$icon" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="24" fill="#2f3f2f"/>
  <path d="M23 83h82a12 12 0 0 1 0 24H23a12 12 0 0 1 0-24Z" fill="#1b241c"/>
  <path d="M35 48h45a16 16 0 0 1 16 16v20H27V56a8 8 0 0 1 8-8Z" fill="#6f8d45"/>
  <path d="M72 38h18a8 8 0 0 1 8 8v17H63V47a9 9 0 0 1 9-9Z" fill="#86a94f"/>
  <path d="M91 47h28a5 5 0 0 1 0 10H91Z" fill="#1b241c"/>
  <circle cx="35" cy="95" r="8" fill="#95a78b"/>
  <circle cx="64" cy="95" r="8" fill="#95a78b"/>
  <circle cx="93" cy="95" r="8" fill="#95a78b"/>
  <path d="M39 61h28v12H39Z" fill="#243324"/>
</svg>
EOF
}

write_desktop_file() {
    desktop="$HOME/.local/share/applications/$APP_ID.desktop"

    cat > "$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Tanks Blitz
Comment=Запуск Tanks Blitz через Proton
Exec=$BIN_DIR/tanks
Icon=$APP_DIR/tanks.svg
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
    package="$DOWNLOAD_DIR/lesta_game_center_install_ru.dspkg"
    target="$APP_DIR/compat/pfx/drive_c/Program Files (x86)/Lesta/GameCenter"

    mkdir -p "$target"

    say "Распаковываю Lesta Game Center..."

    if [ "${EXTRACTOR:-}" = "bsdtar" ]; then
        bsdtar -xf "$package" -C "$target"
    else
        "$EXTRACTOR" x -y "-o$target" "$package" >/dev/null
    fi

    write_lgc_data
}

install_all() {
    ensure_base_dirs
    check_tools || return 1
    ask_prime_run
    install_system_deps || return 1
    detect_extractor || return 1
    write_config
    install_proton || return 1
    download_lgc || return 1
    write_launcher
    write_icon_file
    write_desktop_file
    clean_shortcuts
    copy_self
    ensure_path
    run_lgc_installer || return 1
    verify_lgc_installed || return 1
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
