Description

Description
YAMS installs and configures a complete media server stack using Docker containers:

Download Management:
qBittorrent - Torrent client

Media Management:
Sonarr - TV show management and automation
Radarr - Movie management and automation
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

Installation
Quick installation:
///
git clone --depth=1 https://github.com/userkbmsr-png/yasm2 /tmp/yams
cd /tmp/yams
bash install.sh
///

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

Original has been forked by https://gitlab.com/rogs/yams
Originalmedia/config/

