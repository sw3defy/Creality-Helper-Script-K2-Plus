#!/bin/sh
# fluidd.sh - Install, repair, or remove Fluidd for K2 Plus
#
# The K2 Plus ships with Fluidd pre-installed at /usr/share/fluidd served on port 4408.
# This script can:
#   install  - download and install the latest Fluidd (replaces stock or broken install)
#   remove   - remove Fluidd static files (nginx block stays, port 4408 will 404)
#   restore  - restore the nginx config to serve Fluidd on port 4408

SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

FLUIDD_DIR=/usr/share/fluidd
FLUIDD_URL=https://github.com/fluidd-core/fluidd/releases/latest/download/fluidd.zip
NGINX_CONF=/etc/nginx/nginx.conf

# Stock nginx server block for Fluidd — matches what ships on the K2 Plus
STOCK_FLUIDD_BLOCK='    server {
        listen 4408 default_server;

        access_log /var/log/nginx/fluidd-access.log;
        error_log /var/log/nginx/fluidd-error.log;

        gzip on;
        gzip_vary on;
        gzip_proxied any;
        gzip_proxied expired no-cache no-store private auth;
        gzip_comp_level 4;
        gzip_buffers 16 8k;
        gzip_http_version 1.1;
        gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/json application/xml;

        root /usr/share/fluidd;
        index index.html;
        server_name _;
        client_max_body_size 0;
        proxy_request_buffering off;

        location / {
            try_files $uri $uri/ /index.html;
        }
        location = /index.html {
            add_header Cache-Control "no-store, no-cache, must-revalidate";
        }
        location /websocket {
            proxy_pass http://apiserver/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_read_timeout 86400;
        }
        location ~ ^/(printer|api|access|machine|server)/ {
            proxy_pass http://apiserver$request_uri;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Scheme $scheme;
        }
        location /webcam/  { proxy_pass http://mjpgstreamer1/; }
        location /webcam2/ { proxy_pass http://mjpgstreamer2/; }
        location /webcam3/ { proxy_pass http://mjpgstreamer3/; }
        location /webcam4/ { proxy_pass http://mjpgstreamer4/; }
    }'

# ── Check internet ────────────────────────────────────────────────────────────

check_download_tool() {
    if which wget > /dev/null 2>&1; then
        DOWNLOAD_CMD="wget"
    elif which curl > /dev/null 2>&1; then
        DOWNLOAD_CMD="curl"
    else
        log_error "Neither wget nor curl found. Install Entware first or check your PATH."
        return 1
    fi
}

download_file() {
    local url="$1"
    local dest="$2"
    if [ "$DOWNLOAD_CMD" = "wget" ]; then
        wget -q --show-progress -O "$dest" "$url"
    else
        curl -L --progress-bar -o "$dest" "$url"
    fi
}

# ── Nginx: check and restore Fluidd block ────────────────────────────────────

check_fluidd_nginx_block() {
    grep -q "listen 4408" "$NGINX_CONF" 2>/dev/null
}

restore_fluidd_nginx_block() {
    if check_fluidd_nginx_block; then
        log_info "Fluidd nginx block (port 4408) already present."
        return 0
    fi

    log_info "Adding Fluidd nginx block on port 4408..."
    backup_nginx_conf

    python3 - << PYEOF
with open('$NGINX_CONF') as f:
    content = f.read()

fluidd_block = """
$STOCK_FLUIDD_BLOCK
"""

# Insert before the closing brace of the http block
content = content.rstrip()
if content.endswith('}'):
    content = content[:-1] + fluidd_block + '\n}'

with open('$NGINX_CONF', 'w') as f:
    f.write(content)
print("Fluidd nginx block restored on port 4408.")
PYEOF

    restart_nginx
}

# ── Install / repair Fluidd ───────────────────────────────────────────────────

install_fluidd() {
    echo ""

    # Detect whether this is a fresh install or a repair
    if [ -d "$FLUIDD_DIR" ] && [ -f "$FLUIDD_DIR/index.html" ]; then
        echo -e "${YELLOW}Fluidd is already installed at $FLUIDD_DIR.${NC}"
        echo ""
        echo "  1) Update to the latest version"
        echo "  2) Repair (re-download and reinstall current latest)"
        echo "  0) Cancel"
        echo ""
        printf "  Enter choice: "
        read subchoice
        case "$subchoice" in
            1|2) : ;;  # continue with install
            *)  log_info "Cancelled."; return 0 ;;
        esac
    else
        log_info "Installing Fluidd..."
    fi

    echo ""
    check_download_tool || return 1

    # Get current installed version if present
    if [ -f "$FLUIDD_DIR/version" ]; then
        CURRENT_VER=$(cat "$FLUIDD_DIR/version")
        log_info "Current version: $CURRENT_VER"
    fi

    log_info "Downloading latest Fluidd..."
    download_file "$FLUIDD_URL" /tmp/fluidd.zip

    if [ ! -f /tmp/fluidd.zip ] || [ ! -s /tmp/fluidd.zip ]; then
        log_error "Download failed. Check your internet connection."
        rm -f /tmp/fluidd.zip
        return 1
    fi

    log_info "Installing Fluidd to $FLUIDD_DIR..."
    mkdir -p "$FLUIDD_DIR"
    unzip -q -o /tmp/fluidd.zip -d "$FLUIDD_DIR"
    rm -f /tmp/fluidd.zip

    if [ ! -f "$FLUIDD_DIR/index.html" ]; then
        log_error "Installation failed — index.html not found after extraction."
        return 1
    fi

    # Ensure nginx block is in place
    restore_fluidd_nginx_block

    # Restart nginx to serve updated files
    restart_nginx

    # Show installed version
    if [ -f "$FLUIDD_DIR/version" ]; then
        NEW_VER=$(cat "$FLUIDD_DIR/version")
        log_success "Fluidd installed: version $NEW_VER"
    else
        log_success "Fluidd installed successfully."
    fi

    mark_installed "fluidd_updated"
    echo ""
    log_info "Access Fluidd at: http://$(hostname -I | awk '{print $1}'):4408"
    echo ""
}

# ── Remove Fluidd static files ────────────────────────────────────────────────

remove_fluidd() {
    echo ""
    echo -e "${YELLOW}WARNING: This removes the Fluidd web interface static files.${NC}"
    echo "Port 4408 will return a 404 until Fluidd is reinstalled."
    echo "Moonraker and Klipper continue running normally."
    echo ""
    printf "Are you sure? [y/N]: "
    read confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Cancelled."
        return 0
    fi

    log_info "Removing Fluidd static files from $FLUIDD_DIR..."
    rm -rf "$FLUIDD_DIR"
    mkdir -p "$FLUIDD_DIR"  # keep the directory so nginx doesn't error on root

    restart_nginx
    mark_removed "fluidd_updated"
    echo ""
    log_success "Fluidd removed."
    log_info "To reinstall, run this script again and select Install."
    echo ""
}

# ── Status ────────────────────────────────────────────────────────────────────

status_fluidd() {
    echo ""
    echo "Fluidd status:"
    if [ -f "$FLUIDD_DIR/index.html" ]; then
        log_success "Static files present at $FLUIDD_DIR"
        if [ -f "$FLUIDD_DIR/version" ]; then
            echo "  Version: $(cat $FLUIDD_DIR/version)"
        fi
    else
        log_warn "Static files NOT found at $FLUIDD_DIR"
    fi

    if check_fluidd_nginx_block; then
        log_success "Nginx block present (port 4408)"
    else
        log_warn "Nginx block NOT found for port 4408"
    fi

    if pgrep -f nginx > /dev/null; then
        log_success "Nginx is running"
    else
        log_warn "Nginx is NOT running"
    fi
    echo ""
}

# ── Entry point ───────────────────────────────────────────────────────────────

case "$1" in
    install) install_fluidd ;;
    remove)  remove_fluidd ;;
    restore) restore_fluidd_nginx_block; restart_nginx ;;
    status)  status_fluidd ;;
    *)       echo "Usage: $0 [install|remove|restore|status]" ;;
esac
