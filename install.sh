#!/bin/bash
#
# PC Intel x64 - Debian 13 (trixie)
# Instalează: Stremio (Docker, pornește automat la boot) + Nuvio + stack-ul
# Rulare: sudo bash install.sh

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Rulează cu sudo: sudo bash $0"
    exit 1
fi

KIOSK_USER="${SUDO_USER:-$(logname)}"
KIOSK_HOME="/home/$KIOSK_USER"
STREMIO_PORT=8000
JELLYFIN_PORT=8096
SCRYER_PORT=8585
YAMS_INSTALL_DIR=/opt/yams
YAMS_MEDIA_DIR=/srv/media

echo -e "\e[1;35m"
echo "███╗   ███╗███████╗██████╗ ██╗ █████╗ "
echo "████╗ ████║██╔════╝██╔══██╗██║██╔══██╗"
echo "██╔████╔██║█████╗  ██║  ██║██║███████║"
echo "██║╚██╔╝██║██╔══╝  ██║  ██║██║██╔══██║"
echo "██║ ╚═╝ ██║███████╗██████╔╝██║██║  ██║"
echo "╚═╝     ╚═╝╚══════╝╚═════╝ ╚═╝╚═╝  ╚═╝"
echo -e "\e[1;33m"
echo "                   R R"
echo -e "\e[0m"

echo -e "\e[0;32m[INFO]\e[0m Preparing Stremio/Nuvio installation..."

PRIMARY_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | head -n1)
if [ -z "$PRIMARY_IP" ]; then
    PRIMARY_IP="127.0.0.1"
    echo "!!! Nu am putut detecta IP-ul principal - Jellyfin/Scryer vor rămâne"
    echo "!!! pe localhost, probabil nu vor porni corect din selector."
fi

echo ">>> [1/10] Actualizare sistem..."
apt update && apt upgrade -y

echo ">>> [2/10] Instalare X, i3, Chromium, rofi (minimal, fără recommends)..."
apt install -y --no-install-recommends \
    xserver-xorg \
    xinit \
    x11-xserver-utils \
    i3 \
    chromium \
    rofi \
    unclutter \
    dbus-x11 \
    curl \
    wget \
    git \
    sed \
    gawk

echo ">>> [3/10] Instalare Docker..."
if ! command -v docker &> /dev/null; then
    wget -qO- https://get.docker.com | sh
    usermod -aG docker "$KIOSK_USER"
else
    echo "Docker deja instalat, sar peste."
fi
systemctl enable --now docker

echo ">>> [4/10] Pornire container Stremio (server + web player)..."
mkdir -p "$KIOSK_HOME"/stremio-data
chown "$KIOSK_USER":"$KIOSK_USER" "$KIOSK_HOME"/stremio-data

docker rm -f stremio-docker 2>/dev/null || true
docker run -d \
    --name=stremio-docker \
    -e NO_CORS=1 \
    -e AUTO_SERVER_URL=1 \
    -v "$KIOSK_HOME"/stremio-data:/root/.stremio-server \
    -p "${STREMIO_PORT}:8080/tcp" \
    --restart unless-stopped \
    tsaridas/stremio-docker:latest

echo ">>> [5/10] Instalare Nuvio (întotdeauna alpha - vezi nota din antet)..."
echo "    (~150MB - poate dura câteva minute, în funcție de conexiune)"
cd /tmp
NUVIO_TAG=$(curl -s -o /dev/null -w '%{redirect_url}' "https://github.com/NuvioMedia/NuvioDesktop/releases/latest" | sed 's#.*/tag/##')
NUVIO_DEB_PATH=""
if [ -n "$NUVIO_TAG" ]; then
    NUVIO_DEB_PATH=$(curl -s "https://github.com/NuvioMedia/NuvioDesktop/releases/expanded_assets/${NUVIO_TAG}" \
        | grep -oE 'href="[^"]*\.deb"' | head -n1 | sed 's/href="//;s/"$//')
fi

if [ -z "$NUVIO_TAG" ] || [ -z "$NUVIO_DEB_PATH" ]; then
    echo "!!! Nu am putut detecta automat ultima versiune Nuvio - sar peste."
    echo "!!! Stremio rămâne complet funcțional."
else
    NUVIO_DEB="nuvio_${NUVIO_TAG}_amd64.deb"
    wget -O "$NUVIO_DEB" "https://github.com${NUVIO_DEB_PATH}"
    if [ -f "$NUVIO_DEB" ] && [ "$(stat -c%s "$NUVIO_DEB" 2>/dev/null || echo 0)" -gt 1000000 ]; then
        dpkg -i "$NUVIO_DEB" || true
        if [ -f /var/lib/dpkg/info/nuvio.postinst ]; then
            sed -i 's/^xdg-desktop-menu install/#&/' /var/lib/dpkg/info/nuvio.postinst
        fi
        if apt-get install -f -y; then
            echo "Nuvio $NUVIO_TAG instalat."
        else
            echo "!!! Configurarea Nuvio a eșuat - Stremio nu e afectat, continui."
        fi
    else
        echo "!!! Fișierul Nuvio pare invalid (prea mic) - sar peste."
    fi
    rm -f "$NUVIO_DEB"
fi

echo ">>> [6/10] Stack YAMS (*arr: Sonarr/Radarr/Bazarr/Prowlarr/qBittorrent + Jellyfin)..."

mkdir -p "$YAMS_INSTALL_DIR" "$YAMS_MEDIA_DIR"
chown "$KIOSK_USER":"$KIOSK_USER" "$YAMS_INSTALL_DIR" "$YAMS_MEDIA_DIR"

cat > /etc/sudoers.d/kiosk-yams <<EOF
Cmnd_Alias YAMS_SETUP = /usr/bin/cp * /usr/local/bin/yams, /usr/bin/chmod +x /usr/local/bin/yams, /usr/bin/chown -R * ${YAMS_MEDIA_DIR}, /usr/bin/chown -R * ${YAMS_INSTALL_DIR}, /usr/bin/chown -R * ${YAMS_INSTALL_DIR}/config
$KIOSK_USER ALL=(root) NOPASSWD: YAMS_SETUP
EOF
chmod 0440 /etc/sudoers.d/kiosk-yams
if ! visudo -c -f /etc/sudoers.d/kiosk-yams > /dev/null 2>&1; then
    echo "!!! sudoers pentru YAMS a ieșit invalid - îl șterg. install.sh va"
    echo "!!! cere parolă manual la pasul de CLI/permisiuni."
    rm -f /etc/sudoers.d/kiosk-yams
fi

rm -rf /tmp/yams
git clone --depth=1 https://github.com/userkbmsr-png/MediaRR /tmp/yams
cd /tmp/yams

if sudo -u "$KIOSK_USER" -H bash -c "yes '' | bash /tmp/yams/install.sh"; then
    echo "YAMS instalat."
else
    echo "!!! Instalarea YAMS a eșuat - restul kiosk-ului (Stremio/Nuvio) nu e"
    echo "!!! afectat. Poți relua manual: cd /tmp/yams && bash install.sh"
fi
cd /
rm -rf /tmp/yams

echo ">>> [7/10] Permisiune poweroff fără parolă pentru $KIOSK_USER..."
cat > /etc/sudoers.d/kiosk-poweroff <<EOF
$KIOSK_USER ALL=(root) NOPASSWD: /usr/bin/systemctl poweroff
EOF
chmod 0440 /etc/sudoers.d/kiosk-poweroff
if ! visudo -c -f /etc/sudoers.d/kiosk-poweroff > /dev/null 2>&1; then
    echo "!!! sudoers pentru poweroff a ieșit invalid - îl șterg."
    rm -f /etc/sudoers.d/kiosk-poweroff
fi

echo ">>> [8/10] Autologin pe tty1 pentru $KIOSK_USER..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF
systemctl daemon-reload
systemctl enable getty@tty1.service

echo ">>> [9/10] Pornire automată X + i3 la login pe tty1..."
PROFILE_FILE="$KIOSK_HOME/.bash_profile"
touch "$PROFILE_FILE"
if ! grep -q "exec startx" "$PROFILE_FILE"; then
cat >> "$PROFILE_FILE" <<'EOF'

if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx
fi
EOF
fi

cat > "$KIOSK_HOME"/.xinitrc <<'EOF'
xset s off
xset -dpms
xset s noblank

sleep 2
OUT=$(xrandr | grep " connected" | cut -d" " -f1)
xrandr --newmode "1080p60_tv" 148.50 1920 2008 2052 2200 1080 1084 1089 1125 +hsync -vsync
xrandr --addmode "$OUT" 1080p60_tv
xrandr --output "$OUT" --mode 1080p60_tv

unclutter --timeout 1 &
exec i3
EOF

echo ">>> [10/10] Stremio auto-start + selector (rofi) + config i3..."

cat > "$KIOSK_HOME"/start-kiosk.sh <<EOF
#!/bin/bash
# Pornește Stremio direct. Când se închide (Mod+Shift+r), predă controlul
# selectorului cu toate opțiunile.
for i in \$(seq 1 30); do
    curl -s -o /dev/null "http://localhost:${STREMIO_PORT}" && break
    sleep 1
done

chromium \\
    --kiosk \\
    --noerrdialogs \\
    --disable-infobars \\
    --no-first-run \\
    --disable-session-crashed-bubble \\
    --check-for-update-interval=31536000 \\
    "http://localhost:${STREMIO_PORT}"

exec "\$HOME"/picker.sh
EOF
chmod +x "$KIOSK_HOME"/start-kiosk.sh

cat > "$KIOSK_HOME"/picker.sh <<EOF
#!/bin/bash
# Selector Stremio / Nuvio / Jellyfin / Scryer / Poweroff - reapare de
# fiecare dată când aplicația aleasă se închide.
JELLYFIN_PORT=${JELLYFIN_PORT}
SCRYER_PORT=${SCRYER_PORT}
HOST_IP=${PRIMARY_IP}
CHROMIUM_FLAGS="--kiosk --noerrdialogs --disable-infobars --no-first-run --disable-session-crashed-bubble --check-for-update-interval=31536000"

while true; do
    CHOICE=\$(printf 'Stremio\nNuvio\nJellyfin\nScryer\nPoweroff\n' | rofi -dmenu -i -p "Alege aplicația" -theme-str 'window {width: 25%;} listview {lines: 5;}')

    case "\$CHOICE" in
        Stremio)  "\$HOME"/start-kiosk.sh ;;
        Nuvio)    /opt/nuvio/bin/Nuvio ;;
        Jellyfin) chromium \$CHROMIUM_FLAGS "http://\$HOST_IP:\$JELLYFIN_PORT" ;;
        Scryer)   chromium \$CHROMIUM_FLAGS "http://\$HOST_IP:\$SCRYER_PORT" ;;
        Poweroff) sudo /usr/bin/systemctl poweroff ;;
        *)        sleep 1 ;;
    esac
done
EOF
chmod +x "$KIOSK_HOME"/picker.sh

mkdir -p "$KIOSK_HOME"/.config/i3
cat > "$KIOSK_HOME"/.config/i3/config <<'EOF'
set $mod Mod4

exec --no-startup-id ~/start-kiosk.sh

bindsym $mod+Shift+r exec --no-startup-id "pkill chromium; pkill Nuvio"
bindsym $mod+Shift+e exit

for_window [class="^Stremio$"] fullscreen enable
for_window [class="^com-nuvio-app-MainKt$"] fullscreen enable
EOF

chown -R "$KIOSK_USER":"$KIOSK_USER" \
    "$PROFILE_FILE" \
    "$KIOSK_HOME"/.xinitrc \
    "$KIOSK_HOME"/.config \
    "$KIOSK_HOME"/start-kiosk.sh \
    "$KIOSK_HOME"/picker.sh

echo
echo "=== Gata. Repornește: sudo reboot ==="
echo "La boot: autologin tty1 -> startx -> i3 -> Stremio direct"
echo "Mod+Shift+r din Stremio -> selector: Stremio / Nuvio / Jellyfin / Scryer / Poweroff"
echo
echo "!!! IP folosit pentru Jellyfin/Scryer în selector: $PRIMARY_IP (alocat prin"
echo "!!! DHCP - se poate schimba la un restart de router). Recomandare: fă o"
echo "!!! rezervare DHCP pentru acest PC din panoul routerului (după adresa MAC),"
echo "!!! nu necesită nicio modificare pe acest PC. Dacă IP-ul chiar se schimbă,"
echo "!!! rulează din nou acest script ca să se actualizeze în selector."
if [ -f /usr/local/bin/yams ]; then
    echo
    echo "Servicii MediaRR (detalii complete în ~$KIOSK_USER/yams_services.txt):"
    cat "$KIOSK_HOME/yams_services.txt" 2>/dev/null || true
fi
