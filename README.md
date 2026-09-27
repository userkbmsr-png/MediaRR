Description
Features
Dependencies
Before Installation
Installation
Usage
Configuration
Future Development
Donations
YAMS Donations: The Very Last Priority 🏆
Special Thanks
Contributors
visitor badge Discord

This is a highly opinionated media server that simplifies the setup and management of your home media collection.

Website: https://yams.media
Code documentation: docs.org
Discord: https://discord.gg/Gwae3tNMST
Matrix: https://matrix.to/#/#yams-space:rogs.me
Description
YAMS installs and configures a complete media server stack using Docker containers:

Download Management:

qBittorrent - Torrent client
SABnzbd - Usenet downloader
Gluetun - VPN client for secure downloads
Media Management:

Sonarr - TV show management and automation
Radarr - Movie management and automation
Lidarr - Music management and automation
Bazarr - Automatic subtitle management
Prowlarr - Indexer management for your \*arr apps
Media Servers (Choose One):

Jellyfin (Recommended) - Open source media server
Emby - Media server with premium features
Plex - Popular media server with advanced features
Management & Monitoring:

Portainer - Container management UI
Watchtower - Automatic container updates
Features
YAMS provides a comprehensive media server solution with:

Smart Media Management: Automatically organizes your media library

Downloads new episodes and movies as they become available
Categorizes content into appropriate folders
Manages music and book collections
Fetches subtitles in your preferred languages
Flexible Media Access: Access your content anywhere

Web interface for browser-based streaming
Apps for mobile devices (iOS/Android)
Smart TV apps
Roku, Apple TV, and other streaming devices
Transcoding for optimal playback on any device
Security and Privacy

Built-in VPN support for secure downloads
User management and sharing controls
SSL/TLS encryption support
Easy Management

Simple CLI interface with `yams` command
Web-based management through Portainer
Automatic container updates via Watchtower
Backup and restore functionality
Dependencies
Required:

Docker
Docker Compose
The installation script can automatically install these on Debian/Ubuntu systems.

Before Installation
Prepare the following:

Installation Location

Default: /opt/yams
Ensure your user has write permissions
Media Directory

Default: /srv/media
Will contain subdirectories:

/srv/media/tvshows: TV series
/srv/media/movies: Movies
/srv/media/music: Music files
/srv/media/books: Books and audiobooks
/srv/media/downloads: Temporary download location
/srv/media/blackhole: Watch folder for torrents
Non-root User

Regular system user to own and manage files
Must have sudo privileges for initial setup
VPN Service (Optional but Recommended)

Supported providers listed at yams.media/advanced/vpn
ProtonVPN recommended for:

Simple configuration
Port forwarding
Installation
Quick installation:

git clone --depth=1 https://gitlab.com/rogs/yams.git /tmp/yams
cd /tmp/yams
bash install.sh
Follow the interactive prompts to configure your installation.

Tested on:

Debian 11/12
Ubuntu 22.04
Usage
YAMS provides a simple CLI interface:

yams - Yet Another Media Server

Usage: yams [command] [options]

Commands:
--help                    displays this help message
restart                   restarts yams services
stop                      stops all yams services
start                     starts yams services
status                    checks yams services status
destroy                   destroy yams services so you can start from scratch
check-vpn                 checks if the VPN is working as expected
backup                    backs up yams to the destination location
update-containers         updates all yams containers

Examples:
  yams start                   # Start all YAMS services
  yams backup /path/to/backup  # Backup YAMS to specified directory
  yams update-containers       # Update all containers
Configuration
Complete configuration guide: https://yams.media/config/

Future Development
Planned features and improvements:

Multiple media server support (Jellyfin/Emby/Plex)
Portainer integration
Update functionality
Lidarr and Readarr integration
Enhanced Usenet support
Alpine-based images for reduced footprint
Additional download clients
Jackett integration (https://yams.media/advanced/add-your-own-containers/)
Request management (Jellyseerr/Overseerr) (https://yams.media/advanced/add-your-own-containers/)
Dashboard integration (Organizr/Heimdall) (https://yams.media/advanced/add-your-own-containers/)
Enhanced themes and customization
WireGuard VPN support (https://yams.media/advanced/wireguard/)
Filebrowser integration (https://yams.media/advanced/add-your-own-containers/)
Jellyfin account management (https://yams.media/advanced/add-your-own-containers/)
Donations
If you'd like to support YAMS, please consider donating to the underlying projects:

linuxserver.io
Sonarr
Radarr
Jellyfin
qBittorrent
SABnzbd
Prowlarr
Bazarr
Gluetun
YAMS Donations: The Very Last Priority 🏆
Okay, so you REALLY want to support YAMS? First, thank you! But honestly, I'm not doing this for money. YAMS is a passion project I created for myself and my friends. If you've already supported the projects above and still want to chip in, here are some options:

Special Thanks
YAMS wouldn't be possible without:

linuxserver.io for amazing Docker images
All the core applications listed above
Contributors (in no particular order!):

xploshioOn
norlis
isaac152
Jay Taggart
Mason Stooksbury
gloof
Metin Bektas
Austin
Loriage (Thank you for the french translation! 🇫🇷)
MoMoiin
ak4zh
zavan (Thank you for the MacOS port! https://gitlab.com/zavan/yams)
not-first
The YAMS community for testing and feedback
https://patorjk.com/software/taag/ for the ascii art!
And most importantly: Thank you for using YAMS! 🙏
