#!/bin/sh
# camera.sh - Install K2 Plus camera support for Fluidd and Mainsail
# Credit: DnG-Crafts (https://github.com/DnG-Crafts/K2-Camera)
#         AlexxIT/go2rtc (https://github.com/AlexxIT/go2rtc)
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"
GO2RTC=$SCRIPT_DIR/go2rtc
GO2RTC_YAML=$SCRIPT_DIR/go2rtc.yaml
K2RTC=$SCRIPT_DIR/k2rtc.py
WATCHDOG=$SCRIPT_DIR/camera_watchdog.py

install_camera() {
    echo ""
    echo ""
    echo "======================================================"
    echo "  Camera Support for Fluidd and Mainsail"
    echo "======================================================"
    echo ""
    echo "  This installs a WebRTC bridge that makes the K2 Plus"
    echo "  camera available in both Fluidd and Mainsail dashboards."
    echo ""
    echo "  Credit: DnG-Crafts and AlexxIT/go2rtc"
    echo ""

    printf "  Continue? [y/n]: "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "Cancelled."; return 0; }
    # Download go2rtc if not present
    if [ ! -f "$GO2RTC" ]; then
        log_info "Downloading go2rtc (ARM)..."
        python3 -c "
import urllib.request
urllib.request.urlretrieve(
    'https://github.com/AlexxIT/go2rtc/releases/latest/download/go2rtc_linux_arm',
    '$GO2RTC'
)
print('Downloaded go2rtc')
"
        chmod +x $GO2RTC
    fi

    # Get printer IP
    PRINTER_IP=$(python3 -c "import subprocess; print(subprocess.check_output(['ip', 'route', 'get', '1']).decode().split('src')[1].strip().split()[0])")

    # Create go2rtc config
    cat > $GO2RTC_YAML << YAML
api:
  listen: :1984
  origin: '*'

streams:
  k2plus:
    - "webrtc:http://127.0.0.1:8090/call/webrtc_local"

webrtc:
  listen: :8555
  candidates:
    - $PRINTER_IP
  ice_servers:
    - urls:
        - stun:stun.l.google.com:19302
YAML

    # Create k2rtc.py bridge
    cat > $K2RTC << 'PYTHON'
#!/usr/bin/env python3
import http.server, urllib.request, json, base64, time

class K2Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        sdp = self.rfile.read(length).decode()
        offer = {'type': 'offer', 'sdp': sdp}
        payload = base64.b64encode(json.dumps(offer).encode())
        req = urllib.request.Request(
            'http://127.0.0.1:8000/call/webrtc_local',
            data=payload, method='POST',
            headers={'Content-Type': 'plain/text'}
        )
        try:
            r = urllib.request.urlopen(req, timeout=10)
            response = r.read()
            decoded = base64.b64decode(response)
            data = json.loads(decoded)
            answer_sdp = data['sdp'].encode()
            time.sleep(0.1)
            self.send_response(200)
            self.send_header('Content-Type', 'application/sdp')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Content-Length', len(answer_sdp))
            self.end_headers()
            self.wfile.write(answer_sdp)
            print('Bridge connected', flush=True)
        except Exception as e:
            print('Error:', e, flush=True)
            self.send_response(500)
            self.end_headers()
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.end_headers()

server = http.server.HTTPServer(('127.0.0.1', 8090), K2Handler)
print('K2 bridge running on 8090', flush=True)
server.serve_forever()
PYTHON

    # Create watchdog
    cat > $WATCHDOG << 'PYTHON'
#!/usr/bin/env python3
import urllib.request, json, time

def reconnect():
    try:
        urllib.request.urlopen('http://127.0.0.1:1984/api/streams?src=k2plus', timeout=10)
        print('Stream reconnected', flush=True)
    except Exception as e:
        print('Reconnect error:', e, flush=True)

print('Camera watchdog started', flush=True)
last_bytes = 0
stale_count = 0
while True:
    try:
        r = urllib.request.urlopen('http://127.0.0.1:1984/api/streams', timeout=3)
        data = json.loads(r.read())
        producers = data.get('k2plus', {}).get('producers', [])
        if not producers:
            print('No producers - reconnecting...', flush=True)
            reconnect()
            stale_count = 0
            last_bytes = 0
        else:
            current_bytes = producers[0].get('bytes_recv', 0)
            if current_bytes == last_bytes:
                stale_count += 1
                if stale_count >= 3:
                    print('Stream stale - reconnecting...', flush=True)
                    reconnect()
                    stale_count = 0
                    last_bytes = 0
            else:
                stale_count = 0
                last_bytes = current_bytes
    except Exception as e:
        print('Watchdog error:', e, flush=True)
        reconnect()
    time.sleep(10)
PYTHON

    # Create startup service
    cat > /etc/rc.d/S99camera << 'SHELL'
#!/bin/sh
HELIX=/mnt/UDISK/helper-script
start() {
    echo "Starting K2 camera bridge..."
    sleep 60
    python3 $HELIX/k2rtc.py >> /tmp/k2rtc.log 2>&1 &
    sleep 2
    $HELIX/go2rtc -config $HELIX/go2rtc.yaml >> /tmp/go2rtc.log 2>&1 &
    echo "Camera bridge started" >> /tmp/camera_startup.log 2>&1
    sleep 5
    python3 $HELIX/camera_watchdog.py >> /tmp/watchdog.log 2>&1 &
}
stop() {
    killall go2rtc 2>/dev/null
    kill $(ps aux | grep k2rtc.py | grep -v grep | awk '{print $1}') 2>/dev/null
    kill $(ps aux | grep camera_watchdog | grep -v grep | awk '{print $1}') 2>/dev/null
}
case "$1" in
    start) start ;;
    stop)  stop ;;
    restart) stop; sleep 1; start ;;
    *) echo "Usage: $0 {start|stop|restart}" ;;
esac
SHELL
    chmod +x /etc/rc.d/S99camera
    cp /etc/rc.d/S99camera /etc/init.d/S99camera

    # Add to rc.local
    python3 -c "
content = open('/etc/rc.local').read()
if 'S99camera' not in content:
    content = content.replace('exit 0', '# K2 Camera bridge\n/etc/rc.d/S99camera start &\nexit 0')
    open('/etc/rc.local', 'w').write(content)
    print('Added to rc.local')
else:
    print('Already in rc.local')
"

    # Add nginx proxy for go2rtc on port 4408 (Fluidd) and 4409 (Mainsail)
    python3 -c "
content = open('/etc/nginx/nginx.conf').read()
if 'go2rtc' not in content:
    # Port 4408 Fluidd block
    old4408 = '        location /webcam/ { proxy_pass http://mjpgstreamer1/; }\n    }\n\n    server {'
    new4408 = '''        location /go2rtc/ {
            proxy_pass http://127.0.0.1:1984/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
            proxy_set_header Host \$http_host;
            proxy_read_timeout 3600;
            proxy_send_timeout 3600;
        }
        location /go2rtc/api/ws {
            proxy_pass http://127.0.0.1:1984/api/ws?src=k2plus;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
            proxy_set_header Host \$http_host;
            proxy_read_timeout 3600;
            proxy_send_timeout 3600;
        }
        location /webcam/ { proxy_pass http://mjpgstreamer1/; }
    }

    server {'''
    content = content.replace(old4408, new4408)
    # Port 4409 Mainsail block - last location before closing
    old4409 = '        location /webcam/ { proxy_pass http://mjpgstreamer1/; }\n    }\n\n}'
    new4409 = '''        location /go2rtc/ {
            proxy_pass http://127.0.0.1:1984/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
            proxy_set_header Host \$http_host;
            proxy_read_timeout 3600;
            proxy_send_timeout 3600;
        }
        location /go2rtc/api/ws {
            proxy_pass http://127.0.0.1:1984/api/ws?src=k2plus&\$args;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
            proxy_set_header Host \$http_host;
            proxy_read_timeout 3600;
            proxy_send_timeout 3600;
        }
        location /webcam/ { proxy_pass http://mjpgstreamer1/; }
    }

}'''
    content = content.replace(old4409, new4409)
    open('/etc/nginx/nginx.conf', 'w').write(content)
    print('Nginx updated for Fluidd and Mainsail')
else:
    print('Nginx already configured')
"

    # Add camera to Moonraker (one entry for both Fluidd and Mainsail)
    python3 -c "
import urllib.request, json, socket
import subprocess; ip = subprocess.check_output(['ip', 'route', 'get', '1']).decode().split('src')[1].strip().split()[0]
for name in ['K2 Camera', 'K2 Camera Mainsail']:
    try:
        req = urllib.request.Request('http://127.0.0.1:7125/server/webcams/item?name=' + name.replace(' ', '%20'), method='DELETE')
        urllib.request.urlopen(req)
    except: pass

camera = {
    'name': 'K2 Camera',
    'location': 'printer',
    'service': 'webrtc-go2rtc',
    'target_fps': 15,
    'stream_url': 'http://' + ip + ':4409/go2rtc/',
    'snapshot_url': 'http://' + ip + ':4409/go2rtc/api/frame.jpeg?src=k2plus',
    'flip_horizontal': False,
    'flip_vertical': False,
    'rotation': 0
}
data = json.dumps(camera).encode()
req = urllib.request.Request(
    'http://127.0.0.1:7125/server/webcams/item',
    data=data, method='POST',
    headers={'Content-Type': 'application/json'}
)
urllib.request.urlopen(req)
print('Camera added to Moonraker')
"

    # Update Fluidd index.html with iframe keepalive and auto-reload
    python3 -c "
import re, socket
import subprocess; ip = subprocess.check_output(['ip', 'route', 'get', '1']).decode().split('src')[1].strip().split()[0]
content = open('/usr/share/fluidd/index.html').read()
content = re.sub(r'<iframe[^>]*go2rtc_keepalive[^>]*>.*?</iframe>', '', content)
content = re.sub(r'<script>\nvar cameraReady.*?</script>', '', content, flags=re.DOTALL)
script = '''<script>
var cameraReady = false;
function enableCamera() {
  try {
    var s = document.querySelector(\"#app\").__vue__.\$store;
    var cams = s.state.webcams.webcams;
    if(cams && cams.length > 0 && !cams[0].enabled) {
      cams[0].enabled = true;
      s.state.webcams.webcams.splice(0, 1, cams[0]);
    }
  } catch(e) {}
}
function checkAndReload() {
  fetch('/go2rtc/api/streams')
    .then(r => r.json())
    .then(data => {
      var stream = data.k2plus;
      var prod = stream && stream.producers && stream.producers[0];
      if(prod) {
        var cons = stream.consumers;
        var senderHasBytes = cons && cons.length > 0 && cons[0].senders &&
          cons[0].senders.some(function(s) { return s.bytes > 0; });
        if(senderHasBytes) {
          cameraReady = true;
          enableCamera();
        } else if(!cameraReady && prod.bytes_recv > 500000 && !sessionStorage.getItem(\'reloaded\')) {
          sessionStorage.setItem(\'reloaded\', \'1\');
          setTimeout(function() { location.reload(); }, 2000);
        }
      }
    })
    .catch(function() {});
}
setTimeout(enableCamera, 2000);
setInterval(checkAndReload, 3000);
</script>'''
content = content.replace('</body>', '<iframe src=\"http://' + ip + ':1984/stream.html?src=k2plus&mode=webrtc\" style=\"display:none;width:1px;height:1px;\" id=\"go2rtc_keepalive\"></iframe>' + script + '</body>')
open('/usr/share/fluidd/index.html', 'w').write(content)
print('Fluidd index.html updated')
"

    # Update Mainsail index.html with enabled cam injection
    python3 -c "
import re
import os
if not os.path.exists('/usr/share/mainsail/index.html'): exit(0)
content = open('/usr/share/mainsail/index.html').read()
content = re.sub(r'<iframe[^>]*go2rtc_keepalive[^>]*>.*?</iframe>', '', content)
content = re.sub(r'<script>.*?enableMainsailCams.*?</script>', '', content, flags=re.DOTALL)
script = '''<script>
function enableMainsailCams() {
  try {
    var s = document.querySelector(\"#app\").__vue__.\$store;
    var cams = s.state.gui.webcams.webcams;
    if(cams && cams.length > 0) {
      var changed = false;
      cams.forEach(function(cam, i) {
        if(!cam.enabled) { s.state.gui.webcams.webcams[i].enabled = true; changed = true; }
      });
      if(changed) s.state.gui.webcams.webcams = s.state.gui.webcams.webcams.slice();
    }
  } catch(e) {}
}
setTimeout(enableMainsailCams, 2000);
setInterval(enableMainsailCams, 5000);
</script>'''
content = content.replace('</body>', script + '</body>')
open('/usr/share/mainsail/index.html', 'w').write(content)
print('Mainsail index.html updated')
"

    /etc/rc.d/S80nginx restart
    mark_installed "camera_support"
    echo ""
    log_success "Camera support installed for Fluidd and Mainsail!"
    log_info "The camera will appear in both dashboards after reboot."
    log_info "Note: Camera takes 60-90 seconds to appear after boot."
}

remove_camera() {
    echo ""
    echo -e "${YELLOW}WARNING: This will remove the K2 camera support.${NC}"
    printf "Are you sure? [y/n]: "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "Cancelled."; return 0; }

    # Stop services
    /etc/rc.d/S99camera stop 2>/dev/null

    # Remove startup entries
    rm -f /etc/rc.d/S99camera
    rm -f /etc/init.d/S99camera
    python3 -c "
content = open('/etc/rc.local').read()
content = content.replace('# K2 Camera bridge\n/etc/rc.d/S99camera start &\n', '')
open('/etc/rc.local', 'w').write(content)
print('Removed from rc.local')
"

    # Remove nginx config
    python3 -c "
import re
content = open('/etc/nginx/nginx.conf').read()
content = re.sub(r'\s*location /go2rtc/.*?}\n', '', content, flags=re.DOTALL)
content = re.sub(r'\s*location /go2rtc/api/ws.*?}\n', '', content, flags=re.DOTALL)
open('/etc/nginx/nginx.conf', 'w').write(content)
print('Nginx restored')
"
    /etc/rc.d/S80nginx restart

    # Remove cameras from Moonraker
    python3 -c "
import urllib.request
for name in ['K2 Camera', 'K2 Camera Mainsail']:
    try:
        req = urllib.request.Request('http://127.0.0.1:7125/server/webcams/item?name=' + name.replace(' ', '%20'), method='DELETE')
        urllib.request.urlopen(req)
        print('Removed:', name)
    except: pass
"

    # Restore Fluidd index.html
    python3 -c "
import re
content = open('/usr/share/fluidd/index.html').read()
content = re.sub(r'<iframe[^>]*go2rtc_keepalive[^>]*></iframe>', '', content)
content = re.sub(r'<script>\nvar cameraReady.*?</script>', '', content, flags=re.DOTALL)
open('/usr/share/fluidd/index.html', 'w').write(content)
print('Fluidd index.html restored')
"

    # Restore Mainsail index.html
    python3 -c "
import re
import os
if not os.path.exists('/usr/share/mainsail/index.html'): exit(0)
content = open('/usr/share/mainsail/index.html').read()
content = re.sub(r'<script>.*?enableMainsailCams.*?</script>', '', content, flags=re.DOTALL)
open('/usr/share/mainsail/index.html', 'w').write(content)
print('Mainsail index.html restored')
"

    mark_removed "camera_support"
    log_success "Camera support removed."
}

case "$1" in
    install) install_camera ;;
    remove)  remove_camera ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
