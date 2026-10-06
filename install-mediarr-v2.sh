#!/bin/bash
#
# install-mediarr.sh (v2)
# PC Intel x64 - Debian 13 (trixie)
#
# Un singur fișier, autonom - fără git clone, fără dependențe externe,
# fără nicio intervenție din partea utilizatorului în timpul rulării.
# Instalează: Stremio (Docker, pornește automat la boot) + Nuvio + Jellyfin
# + Mediarium (docker-compose din https://github.com/rdborg/Mediarium,
# adaptat automat: PUID/PGID/TZ/foldere) + X/i3 minimal + selector (rofi).
#
# Totul pentru Mediarium/Jellyfin stă sub $HOME-ul utilizatorului care
# a rulat sudo (~/mediarr). Stack-ul *arr (Sonarr/Radarr/...) NU se mai
# instalează.
#
# Dacă stack-ul nu pornește din prima (ex. internet căzut), scriptul lasă
# ~/install.sh - un script minimal care doar reia pornirea containerelor.
#
# Rulare: sudo bash install-mediarr.sh
#

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Rulează cu sudo: sudo bash $0"
    exit 1
fi

# Fără nicio întrebare interactivă din apt/dpkg
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
APT_OPTS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

KIOSK_USER="${SUDO_USER:-$(logname)}"
KIOSK_HOME="/home/$KIOSK_USER"
STREMIO_PORT=8000
JELLYFIN_PORT=8096
MEDIARIUM_PORT=8264
MEDIARR_DIR="$KIOSK_HOME/mediarr"

PRIMARY_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | head -n1 || true)
if [ -z "$PRIMARY_IP" ]; then
    PRIMARY_IP="127.0.0.1"
    echo "!!! Nu am putut detecta IP-ul principal - Jellyfin/Mediarium vor rămâne"
    echo "!!! pe localhost, probabil nu vor porni corect din selector."
fi

cat > "$KIOSK_HOME/mediarr-banner.txt" <<'BANNER_EOF'
                               ___,              
                  |  o        /   |              
 _  _  _    _   __|      __, |    |   ,_    ,_   
/ |/ |/ |  |/  /  |  |  /  | |    |  /  |  /  |  
  |  |  |_/|__/\_/|_/|_/\_/|_/\__/\_/   |_/   |_/
BANNER_EOF
chown "$KIOSK_USER":"$KIOSK_USER" "$KIOSK_HOME/mediarr-banner.txt"

echo ">>> [1/10] Actualizare sistem..."
apt-get update
apt-get upgrade "${APT_OPTS[@]}"

echo ">>> [2/10] Instalare X, i3, Chromium, rofi (minimal, fără recommends)..."
apt-get install "${APT_OPTS[@]}" --no-install-recommends \
    xserver-xorg \
    xinit \
    x11-xserver-utils \
    i3 \
    chromium \
    rofi \
    xbindkeys \
    unclutter \
    dbus-x11 \
    curl \
    wget

echo ">>> [3/10] Instalare Docker..."
if ! command -v docker &> /dev/null; then
    wget -qO- https://get.docker.com | sh
else
    echo "Docker deja instalat, sar peste."
fi
usermod -aG docker "$KIOSK_USER"
systemctl enable --now docker

# Plugin-ul "docker compose" e necesar pentru Mediarium; get.docker.com îl
# instalează, dar dacă Docker exista deja fără plugin, îl adăugăm.
if ! docker compose version &> /dev/null; then
    echo "Plugin-ul docker compose lipsește - îl instalez..."
    apt-get install "${APT_OPTS[@]}" docker-compose-plugin
fi

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

echo ">>> [5/10] Instalare Nuvio (întotdeauna alpha - singura versiune publicată)..."
cat "$KIOSK_HOME/mediarr-banner.txt"
echo "    Se descarcă Nuvio (~150MB) - poate dura câteva minute, în funcție de conexiune..."
cd /tmp
NUVIO_TAG=$(curl -s -o /dev/null -w '%{redirect_url}' "https://github.com/NuvioMedia/NuvioDesktop/releases/latest" | sed 's#.*/tag/##')
NUVIO_DEB_PATH=""
if [ -n "$NUVIO_TAG" ]; then
    NUVIO_DEB_PATH=$(curl -s "https://github.com/NuvioMedia/NuvioDesktop/releases/expanded_assets/${NUVIO_TAG}" \
        | grep -oE 'href="[^"]*\.deb"' | head -n1 | sed 's/href="//;s/"$//' || true)
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
        if apt-get install -f "${APT_OPTS[@]}"; then
            echo "Nuvio $NUVIO_TAG instalat."
        else
            echo "!!! Configurarea Nuvio a eșuat - Stremio nu e afectat, continui."
        fi
    else
        echo "!!! Fișierul Nuvio pare invalid (prea mic) - sar peste."
    fi
    rm -f "$NUVIO_DEB"
fi

echo ">>> [6/10] Mediarium + Jellyfin (docker compose, fără intervenție)..."
echo "    Totul sub $MEDIARR_DIR - folderele se creează automat pentru $KIOSK_USER."

PUID=$(id -u "$KIOSK_USER")
PGID=$(id -g "$KIOSK_USER")

# Folderele cerute de docker-compose.yml din Mediarium:
#   ./config  -> /config  (setările și baza de date Mediarium)
#   ./data    -> /data    (downloads + movies + tv [+ music], pe același
#                          volum, ca mutarea să fie prin hardlink)
# Plus un folder separat pentru configul Jellyfin. Docker ar crea singur
# folderele lipsă, dar ca root - de aceea le creăm noi, cu userul curent.
mkdir -p "$MEDIARR_DIR"/config \
         "$MEDIARR_DIR"/jellyfin-config \
         "$MEDIARR_DIR"/data/downloads \
         "$MEDIARR_DIR"/data/movies \
         "$MEDIARR_DIR"/data/tv \
         "$MEDIARR_DIR"/data/music

# Valorile marcate "CHANGE" în yml-ul original (PUID, PGID, TZ) sunt
# completate automat prin .env - nu mai editează nimeni nimic.
cat > "$MEDIARR_DIR/.env" <<EOF
PUID=$PUID
PGID=$PGID
TZ=Europe/Bucharest
EOF

cat > "$MEDIARR_DIR/docker-compose.yml" <<'COMPOSE_EOF'
# Mediarium (https://github.com/rdborg/Mediarium) - docker-compose.yml
# adaptat de install-mediarr.sh: PUID/PGID/TZ vin din .env, folderele
# sunt create în avans, MUSIC_DIR activat, plus Jellyfin pentru redare.
services:
  mediarium:
    image: ghcr.io/rdborg/mediarium:latest
    container_name: mediarium
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "8264:8264"
      - "58264:58264/tcp"
      - "58264:58264/udp"
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - DOWNLOADS_DIR=/data/downloads
      - MOVIES_DIR=/data/movies
      - TV_DIR=/data/tv
      - MUSIC_DIR=/data/music
    volumes:
      - ./config:/config
      - ./data:/data

  # Opțional: doar pentru site-uri din spatele Cloudflare. Nu pornește
  # implicit (profil "cloudflare").
  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    restart: unless-stopped
    profiles: ["cloudflare"]
    environment:
      - TZ=${TZ}

  # Jellyfin: redă ce descarcă Mediarium (biblioteci: /data/movies,
  # /data/tv, /data/music).
  jellyfin:
    image: lscr.io/linuxserver/jellyfin
    container_name: jellyfin
    restart: unless-stopped
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./data:/data
      - ./jellyfin-config:/config
    ports:
      - "8096:8096"
COMPOSE_EOF

chown -R "$KIOSK_USER":"$KIOSK_USER" "$MEDIARR_DIR"

# Pornire cu 3 încercări automate (rețea instabilă / registry ocupat).
# --remove-orphans curăță containerele vechi (sonarr, radarr, ...) dacă
# versiunea anterioară a scriptului a mai rulat pe acest PC.
start_stack() {
    local i
    for i in 1 2 3; do
        if (cd "$MEDIARR_DIR" && docker compose up -d --remove-orphans); then
            return 0
        fi
        echo "!!! Încercarea $i/3 a eșuat - reiau în 10 secunde..."
        sleep 10
    done
    return 1
}

cat "$KIOSK_HOME/mediarr-banner.txt"
echo "Se descarcă imaginile Docker (Mediarium, Jellyfin) - poate dura câteva minute."
if start_stack; then
    echo "Mediarium + Jellyfin pornite cu succes."
else
    echo "!!! Pornirea Mediarium/Jellyfin a eșuat după 3 încercări."
    echo "!!! Scriu un script simplu de reluare: $KIOSK_HOME/install.sh"
    cat > "$KIOSK_HOME/install.sh" <<RETRY_EOF
#!/bin/bash
set -e
cd "$MEDIARR_DIR"
docker compose up -d --remove-orphans
echo "Mediarium + Jellyfin pornite cu succes."
RETRY_EOF
    chmod +x "$KIOSK_HOME/install.sh"
    chown "$KIOSK_USER":"$KIOSK_USER" "$KIOSK_HOME/install.sh"
    echo "!!! Restul kiosk-ului (Stremio/Nuvio) nu e afectat - continui."
    echo "!!! Reia mai târziu cu: bash ~/install.sh"
fi
cd /

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

cat > "$KIOSK_HOME"/.xbindkeysrc <<EOF
"$KIOSK_HOME/app-control.sh toggle"
    m:0x0 + b:3
EOF

cat > "$KIOSK_HOME"/.xinitrc <<'EOF'
xset s off
xset -dpms
xset s noblank

# Forțează modul video corect - la boot, TV-ul poate raporta un EDID
# nesigur/gol, iar X alege atunci un mod cu polaritate sync greșită
# ("Unsupported" pe TV). Aplicăm direct modul confirmat funcțional
# (1920x1080@60, +hsync -vsync, din EDID-ul real al TV-ului).
sleep 2
OUT=$(xrandr | grep " connected" | cut -d" " -f1)
xrandr --newmode "1080p60_tv" 148.50 1920 2008 2052 2200 1080 1084 1089 1125 +hsync -vsync
xrandr --addmode "$OUT" 1080p60_tv
xrandr --output "$OUT" --mode 1080p60_tv

unclutter --timeout 1 &
xbindkeys &
exec i3
EOF

echo ">>> [10/10] Stremio auto-start + selector (rofi) + config i3..."

cat > "$KIOSK_HOME"/app-control.sh <<HEADER_EOF
#!/bin/bash
STREMIO_PORT=${STREMIO_PORT}
JELLYFIN_PORT=${JELLYFIN_PORT}
MEDIARIUM_PORT=${MEDIARIUM_PORT}
HOST_IP=${PRIMARY_IP}
HEADER_EOF

cat >> "$KIOSK_HOME"/app-control.sh <<'BODY_EOF'
CHROMIUM_FLAGS="--kiosk --noerrdialogs --disable-infobars --no-first-run --disable-session-crashed-bubble --check-for-update-interval=31536000"

# Omoară orice e deschis acum (selector inclus) - singurul loc de unde se
# face asta, ca să nu mai existe curse între mai multe comenzi independente
# care porneau/opreau lucruri fără să știe una de alta.
kill_current() {
    pkill rofi 2>/dev/null
    pkill chromium 2>/dev/null
    pkill Nuvio 2>/dev/null
    sleep 0.3
}

launch_stremio() {
    kill_current
    (
        for i in $(seq 1 30); do
            curl -s -o /dev/null "http://localhost:$STREMIO_PORT" && break
            sleep 1
        done
        chromium $CHROMIUM_FLAGS "http://localhost:$STREMIO_PORT"
    ) &
}

launch_nuvio() {
    kill_current
    /opt/nuvio/bin/Nuvio &
}

launch_jellyfin() {
    kill_current
    chromium $CHROMIUM_FLAGS "http://$HOST_IP:$JELLYFIN_PORT" &
}

launch_mediarium() {
    kill_current
    chromium $CHROMIUM_FLAGS "http://$HOST_IP:$MEDIARIUM_PORT" &
}

# Nu omoară nimic înainte să afișeze rofi - rofi apare DEASUPRA aplicației
# curente, fără s-o oprească. Doar dacă alegi ceva, acel ceva (prin
# launch_*) oprește ce rula înainte. Escape/clic-în-afară -> rofi dispare,
# aplicația de dinainte rămâne exact cum era.
show_selector() {
    CHOICE=$(printf 'Stremio\nNuvio\nJellyfin\nMediarium\nPoweroff\n' | rofi -dmenu -i -p "Alege aplicația" -theme-str 'window {width: 25%;} listview {lines: 5;}')
    case "$CHOICE" in
        Stremio)   launch_stremio ;;
        Nuvio)     launch_nuvio ;;
        Jellyfin)  launch_jellyfin ;;
        Mediarium) launch_mediarium ;;
        Poweroff)  sudo /usr/bin/systemctl poweroff ;;
    esac
}

case "$1" in
    toggle)
        if pgrep -x rofi > /dev/null; then
            pkill rofi
        else
            show_selector
        fi
        ;;
    hide)      pkill rofi 2>/dev/null ;;
    poweroff)  sudo /usr/bin/systemctl poweroff ;;
    stremio)   launch_stremio ;;
    nuvio)     launch_nuvio ;;
    jellyfin)  launch_jellyfin ;;
    mediarium) launch_mediarium ;;
    *)         echo "Folosire: $0 {toggle|hide|poweroff|stremio|nuvio|jellyfin|mediarium}" ;;
esac
BODY_EOF
chmod +x "$KIOSK_HOME"/app-control.sh

mkdir -p "$KIOSK_HOME"/.config/i3
cat > "$KIOSK_HOME"/.config/i3/config <<'EOF'
set $mod Mod4

exec --no-startup-id ~/app-control.sh stremio

bindsym $mod+Shift+e exit

# F1 = arată/ascunde selectorul (același efect ca și clic dreapta)
# F2-F5 = lansează direct aplicația respectivă
# F6 = poweroff
bindsym F1 exec --no-startup-id "~/app-control.sh toggle"
bindsym F2 exec --no-startup-id "~/app-control.sh stremio"
bindsym F3 exec --no-startup-id "~/app-control.sh nuvio"
bindsym F4 exec --no-startup-id "~/app-control.sh jellyfin"
bindsym F5 exec --no-startup-id "~/app-control.sh mediarium"
bindsym F6 exec --no-startup-id "~/app-control.sh poweroff"

for_window [class="^Stremio$"] fullscreen enable
for_window [class="^com-nuvio-app-MainKt$"] fullscreen enable
EOF

chown -R "$KIOSK_USER":"$KIOSK_USER" \
    "$PROFILE_FILE" \
    "$KIOSK_HOME"/.xinitrc \
    "$KIOSK_HOME"/.xbindkeysrc \
    "$KIOSK_HOME"/.config \
    "$KIOSK_HOME"/app-control.sh

echo
echo "=== Gata. Repornește: sudo reboot ==="
echo "La boot: autologin tty1 -> startx -> i3 -> Stremio direct"
echo "Clic dreapta (oriunde) -> arată/ascunde selectorul: Stremio / Nuvio / Jellyfin / Mediarium / Poweroff"
echo "Cu tastatură, dacă e conectată: F1 selector, F2 Stremio, F3 Nuvio, F4 Jellyfin, F5 Mediarium, F6 poweroff"
echo
echo "Mediarium: http://$PRIMARY_IP:$MEDIARIUM_PORT  (primul pas: wizardul de configurare)"
echo "Jellyfin:  http://$PRIMARY_IP:$JELLYFIN_PORT  (biblioteci: /data/movies, /data/tv, /data/music)"
echo "Foldere:   $MEDIARR_DIR/{config,data,jellyfin-config}"
echo
echo "!!! IP folosit pentru Jellyfin/Mediarium în selector: $PRIMARY_IP (alocat prin"
echo "!!! DHCP - se poate schimba la un restart de router). Recomandare: fă o"
echo "!!! rezervare DHCP pentru acest PC din panoul routerului (după adresa MAC)."
if [ -f "$KIOSK_HOME/install.sh" ]; then
    echo
    echo "!!! Mediarium/Jellyfin nu au pornit din prima - rulează: bash ~/install.sh"
fi
