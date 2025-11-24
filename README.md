# Plesk → Proxmox Mail Gateway Domain Sync Script

This repository contains a bash script that automatically synchronizes all add-on domains in Plesk with a Proxmox Mail Gateway (PMG) server.
This script was based on the initial script of https://github.com/JrZavaschi/cpanel-to-pmg-domains-sync

Features:
- Fetches all domains from Plesk
- Syncs them with PMG via API
- Automatically adds new domains
- Removes deleted domains

Configuration
The settings are simple:

PMG_IP="xxx.xxx.xxx.xxx" #IP or host

PMG_USER="user@pmg" # user@pmg

PMG_PASSWORD="password-user-pmg"

CPANEL_HOST="host-cpanel" #only host cpanel server

RECIPIENT_EMAIL="support@support.com"

DATA=/bin/date '+%Y-%m-%d %T'

LOG_FILE="/var/log/pmg_sync.log"
