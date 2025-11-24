#!/bin/bash
# VizraPlesk → PMG Domain Sync Script
# www.vizra.com 
# Samet YILMAZ

# Proxmox Mail Gateway Credentials
PMG_IP="PMG_IP"
PMG_USER="root@pmg"
PMG_PASSWORD="PMG_PASSWORD"
PLESK_HOST="ms1.vizra.com"
RECIPIENT_EMAIL="support@vizra.com"
DATA=`/bin/date '+%Y-%m-%d %T'`
LOG_FILE="/var/log/pmg_sync.log"

log() {
    echo "[$(date '+%Y-%m-%d %T')] $1"
}

### 1. AUTH TICKET ###
log "Getting authentication ticket from PMG..."
AUTH_RESPONSE=$(curl -s -k -X POST \
    --data-urlencode "username=$PMG_USER" \
    --data-urlencode "password=$PMG_PASSWORD" \
    "https://$PMG_IP:8006/api2/json/access/ticket")

if ! echo "$AUTH_RESPONSE" | grep -q '"data":'; then
    log "ERROR: Authentication failed."
    exit 1
fi

TICKET=$(echo "$AUTH_RESPONSE" | grep -o '"ticket":"[^"]*' | cut -d'"' -f4)
CSRF_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"CSRFPreventionToken":"[^"]*' | cut -d'"' -f4)

### 2. GET DOMAIN LIST FROM PLESK ###
log "Fetching domains from Plesk..."

DOMAINS_PLESK=$(/usr/sbin/plesk bin domain --list)

if [ -z "$DOMAINS_PLESK" ]; then
    log "No domains found on Plesk."
fi

### 3. GET DOMAINS FROM PMG ###
log "Fetching domains from PMG..."

RESPONSE_DOMAINS_PMG=$(curl -s -k -b "PMGAuthCookie=$TICKET" \
    -H "CSRFPreventionToken: $CSRF_TOKEN" \
    -X GET \
    "https://$PMG_IP:8006/api2/json/config/transport")

DOMAINS_PMG=$(echo "$RESPONSE_DOMAINS_PMG" \
    | jq --arg host "$PLESK_HOST" -r '.data[] | select(.host == $host) | .domain')

### VARIABLES ###
NEW_DOMAINS=""
REMOVED_DOMAINS=""

### 4. ADD MISSING DOMAINS TO PMG ###
log "Syncing domains: adding new ones..."

for domain in $DOMAINS_PLESK; do
    if ! echo "$DOMAINS_PMG" | grep -q "^$domain$"; then
        log "Adding domain: $domain"

        # ADD RELAY DOMAIN
        ADD_RELAY=$(curl -s -k -b "PMGAuthCookie=$TICKET" \
            -H "CSRFPreventionToken: $CSRF_TOKEN" \
            -X POST \
            -H "Content-Type: application/json" \
            -d "{\"domain\":\"$domain\"}" \
            "https://$PMG_IP:8006/api2/json/config/domains")

        # ADD TRANSPORT
        ADD_TRANSPORT=$(curl -s -k -b "PMGAuthCookie=$TICKET" \
            -H "CSRFPreventionToken: $CSRF_TOKEN" \
            -X POST \
            -H "Content-Type: application/json" \
            --data '{"domain": "'"$domain"'", "host": "'"$PLESK_HOST"'", "port": 25, "comment": "Plesk Sync '"$DATA"'", "protocol": "smtp", "use_mx": false}' \
            "https://$PMG_IP:8006/api2/json/config/transport")

        NEW_DOMAINS+="$domain\n"
    else
        log "Domain exists in PMG: $domain"
    fi
done

### 5. REMOVE DOMAINS NOT IN PLESK ###
log "Syncing domains: removing obsolete..."

for domain in $DOMAINS_PMG; do
    if ! echo "$DOMAINS_PLESK" | grep -q "^$domain$"; then
        log "Removing domain from PMG: $domain"

        # DELETE RELAY DOMAIN
        curl -s -k -b "PMGAuthCookie=$TICKET" \
            -H "CSRFPreventionToken: $CSRF_TOKEN" \
            -X DELETE \
            "https://$PMG_IP:8006/api2/json/config/domains/$domain"

        # DELETE TRANSPORT
        curl -s -k -b "PMGAuthCookie=$TICKET" \
            -H "CSRFPreventionToken: $CSRF_TOKEN" \
            -X DELETE \
            "https://$PMG_IP:8006/api2/json/config/transport/$domain"

        REMOVED_DOMAINS+="$domain\n"
    fi
done

log "Sync complete."
