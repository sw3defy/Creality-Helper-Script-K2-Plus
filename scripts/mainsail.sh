#!/bin/sh
# mainsail.sh - Install, update, repair, or remove Mainsail on port 4409 for K2 Plus

SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

MAINSAIL_DIR=/usr/share/mainsail
MAINSAIL_URL=https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip
NGINX_CONF=/etc/nginx/nginx.conf

# ── Download helper ───────────────────────────────────────────────────────────

check_download_tool() {
    DOWNLOAD_CMD="python3"
}

download_file() {
    local url="$1"
    local dest="$2"
    python3 -c "import urllib.request; urllib.request.urlretrieve('$url', '$dest'); print('Downloaded')"
}

# ── Nginx block management ────────────────────────────────────────────────────

check_mainsail_nginx_block() {
    grep -q "listen 4409" "$NGINX_CONF" 2>/dev/null
}

restore_mainsail_nginx_block() {
    if check_mainsail_nginx_block; then
        log_info "Mainsail nginx block (port 4409) already present."
        return 0
    fi

    log_info "Adding Mainsail nginx block on port 4409..."
    backup_nginx_conf

    python3 - << PYEOF
with open('$NGINX_CONF') as f:
    content = f.read()

mainsail_block = """
    server {
        listen 4409 default_server;

        access_log /var/log/nginx/mainsail-access.log;
        error_log /var/log/nginx/mainsail-error.log;

        gzip on;
        gzip_vary on;
        gzip_proxied any;
        gzip_comp_level 4;
        gzip_buffers 16 8k;
        gzip_http_version 1.1;
        gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/json application/xml;

        root /usr/share/mainsail;
        index index.html;
        server_name _;
        client_max_body_size 0;
        proxy_request_buffering off;

        location / {
            try_files \$uri \$uri/ /index.html;
        }
        location = /index.html {
            add_header Cache-Control "no-store, no-cache, must-revalidate";
        }
        location /websocket {
            proxy_pass http://apiserver/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_read_timeout 86400;
        }
        location ~ ^/(printer|api|access|machine|server)/ {
            proxy_pass http://apiserver\$request_uri;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Scheme \$scheme;
        }
        location /webcam/  { proxy_pass http://mjpgstreamer1/; }
        location /webcam2/ { proxy_pass http://mjpgstreamer2/; }
        location /webcam3/ { proxy_pass http://mjpgstreamer3/; }
        location /webcam4/ { proxy_pass http://mjpgstreamer4/; }
    }
"""

content = content.rstrip()
if content.endswith('}'):
    content = content[:-1] + mainsail_block + '\n}'

with open('$NGINX_CONF', 'w') as f:
    f.write(content)
print("Mainsail nginx block added on port 4409.")
PYEOF

    restart_nginx force
    log_success "Mainsail nginx block restored on port 4409."
}

remove_mainsail_nginx_block() {
    if ! check_mainsail_nginx_block; then
        log_info "Mainsail nginx block not found — nothing to remove."
        return 0
    fi

    log_info "Removing Mainsail nginx block from nginx.conf..."
    python3 - << PYEOF
with open("$NGINX_CONF") as f:
    file_lines = f.readlines()
new_lines = []
skip = False
brace_count = 0
for line in file_lines:
    if not skip and "listen 4409" in line:
        for i in range(len(new_lines)-1, -1, -1):
            if new_lines[i].strip().startswith("server"):
                new_lines = new_lines[:i]
                break
        skip = True
        brace_count = 1
        continue
    if skip:
        brace_count += line.count("{") - line.count("}")
        if brace_count <= 0:
            skip = False
        continue
    new_lines.append(line)
with open("$NGINX_CONF", "w") as f:
    f.writelines(new_lines)
print("Mainsail nginx block removed.")
PYEOF
    log_success "Mainsail nginx block removed."
}

# ── Status ────────────────────────────────────────────────────────────────────

status_mainsail() {
    echo ""
    echo "Mainsail status:"
    if [ -f "$MAINSAIL_DIR/index.html" ]; then
        log_success "Static files present at $MAINSAIL_DIR"
        if [ -f "$MAINSAIL_DIR/version" ]; then
            echo "  Version: $(cat $MAINSAIL_DIR/version)"
        fi
    else
        log_warn "Static files NOT found at $MAINSAIL_DIR"
    fi

    if check_mainsail_nginx_block; then
        log_success "Nginx block present (port 4409)"
    else
        log_warn "Nginx block NOT found for port 4409"
    fi

    if pgrep -f nginx > /dev/null; then
        log_success "Nginx is running"
    else
        log_warn "Nginx is NOT running"
    fi
    echo ""
}

# ── Install / update / repair ─────────────────────────────────────────────────

install_mainsail() {
    echo ""

    # Detect whether this is a fresh install or update/repair
    if [ -d "$MAINSAIL_DIR" ] && [ -f "$MAINSAIL_DIR/index.html" ]; then
        echo -e "${YELLOW}Mainsail is already installed at $MAINSAIL_DIR.${NC}"
        if [ -f "$MAINSAIL_DIR/version" ]; then
            echo "  Current version: $(cat $MAINSAIL_DIR/version)"
        fi
        echo ""
        echo "  1) Update to the latest version"
        echo "  2) Repair (re-download and reinstall)"
        echo "  3) Restore nginx block only (if port 4409 is broken)"
        echo "  0) Cancel"
        echo ""
        printf "  Enter choice: "
        read subchoice
        case "$subchoice" in
            1|2) : ;;  # continue with full install
            3)  restore_mainsail_nginx_block; return 0 ;;
            *)  log_info "Cancelled."; return 0 ;;
        esac
    else
        log_info "Installing Mainsail..."
    fi

    echo ""
    log_info "Downloading latest Mainsail..."
    python3 << PYEOF || { log_error "Download failed. Check your internet connection."; return 1; }
import urllib.request, zipfile, os
os.makedirs('$MAINSAIL_DIR', exist_ok=True)
print('Downloading Mainsail...')
urllib.request.urlretrieve('$MAINSAIL_URL', '/tmp/mainsail.zip')
print('Extracting...')
with zipfile.ZipFile('/tmp/mainsail.zip', 'r') as z:
    z.extractall('$MAINSAIL_DIR')
os.remove('/tmp/mainsail.zip')
print('Done')
PYEOF

    if [ ! -f "$MAINSAIL_DIR/index.html" ]; then
        log_error "Installation failed — index.html not found after extraction."
        return 1
    fi

    # Ensure nginx block is in place
    restore_mainsail_nginx_block

    restart_nginx force

    if [ -f "$MAINSAIL_DIR/version" ]; then
        NEW_VER=$(cat "$MAINSAIL_DIR/version")
        log_success "Mainsail installed: version $NEW_VER"
    else
        log_success "Mainsail installed successfully."
    fi

    mark_installed "mainsail"
    echo ""
    log_info "Access Mainsail at: http://$(ip route get 1 | grep -o 'src [0-9.]*' | awk '{print $2}'):4409"
    echo ""
}

# ── Remove ────────────────────────────────────────────────────────────────────

remove_mainsail() {
    if ! is_installed "mainsail"; then
        log_info "Mainsail is not installed."
        return 0
    fi
        echo ""
    echo -e "${YELLOW}WARNING: This removes Mainsail static files and the port 4409 nginx block.${NC}"
    echo "Fluidd on port 4408 is not affected."
    echo ""
    printf "Are you sure? [y/n]: "
    read confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Cancelled."
        return 0
    fi

    remove_mainsail_nginx_block
    rm -rf "$MAINSAIL_DIR"
    restart_nginx force
    mark_removed "mainsail"
    echo ""
    log_success "Mainsail removed."
    log_info "Fluidd on port 4408 is unaffected."
    echo ""
}

# ── Entry point ───────────────────────────────────────────────────────────────

case "$1" in
    install) install_mainsail ;;
    remove)  remove_mainsail ;;
    restore) restore_mainsail_nginx_block; restart_nginx ;;
    status)  status_mainsail ;;
    *)       echo "Usage: $0 [install|remove|restore|status]" ;;
esac
