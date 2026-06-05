#!/bin/sh
# camera.sh - Install/remove Python3 MJPEG camera streamer for K2 Plus
#
# WARNING: Installing this will break the camera in Creality Print and
# on the touchscreen. It is fully reversible via the remove option.

SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

CAMERA_SCRIPT=/mnt/UDISK/helper-script/mjpeg_streamer.py
CAMERA_RC=/etc/rc.d/S96mjpeg_streamer
CAM_APP_RC=/etc/rc.d/S50cam_app

install_camera() {
    echo ""
    echo -e "${YELLOW}WARNING: This will break the camera in Creality Print and touchscreen.${NC}"
    echo "The camera will work in Fluidd and Mainsail instead."
    echo "This change is fully reversible."
    echo ""
    printf "Continue? [y/N]: "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { log_info "Cancelled."; return 0; }

    log_info "Installing MJPEG Camera Streamer..."

    # Write the Python3 MJPEG streamer
    cat > "$CAMERA_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3
"""
MJPEG Camera Streamer for K2 Plus
Serves camera frames on port 8080 for Fluidd/Mainsail
"""
import fcntl, mmap, os, socket, threading, struct, time, ctypes, signal, sys

DEVICE = '/dev/v4l/by-id/main-video0'
PORT = 8080
WIDTH = 1280
HEIGHT = 720
FPS = 15

V4L2_BUF_TYPE_VIDEO_CAPTURE = 1
V4L2_MEMORY_MMAP = 1
V4L2_FIELD_ANY = 0
V4L2_PIX_FMT_MJPEG = 0x47504A4D
VIDIOC_S_FMT    = 0xC0CC5605
VIDIOC_REQBUFS  = 0xC0145608
VIDIOC_QUERYBUF = 0xC0445609
VIDIOC_QBUF     = 0xC044560F
VIDIOC_DQBUF    = 0xC0445611
VIDIOC_STREAMON = 0x40045612

frame_lock = threading.Lock()
current_frame = None

def setup_camera():
    fd = os.open(DEVICE, os.O_RDWR | os.O_NONBLOCK)
    fmt = ctypes.create_string_buffer(204)
    struct.pack_into('<I', fmt, 0, V4L2_BUF_TYPE_VIDEO_CAPTURE)
    struct.pack_into('<I', fmt, 4, WIDTH)
    struct.pack_into('<I', fmt, 8, HEIGHT)
    struct.pack_into('<I', fmt, 12, V4L2_PIX_FMT_MJPEG)
    struct.pack_into('<I', fmt, 16, V4L2_FIELD_ANY)
    fcntl.ioctl(fd, VIDIOC_S_FMT, fmt)

    req = ctypes.create_string_buffer(32)
    struct.pack_into('<I', req, 0, 4)
    struct.pack_into('<I', req, 4, V4L2_BUF_TYPE_VIDEO_CAPTURE)
    struct.pack_into('<I', req, 8, V4L2_MEMORY_MMAP)
    fcntl.ioctl(fd, VIDIOC_REQBUFS, req)
    count = struct.unpack_from('<I', req, 0)[0]

    buffers = []
    for i in range(count):
        buf = ctypes.create_string_buffer(88)
        struct.pack_into('<I', buf, 0, V4L2_BUF_TYPE_VIDEO_CAPTURE)
        struct.pack_into('<I', buf, 4, i)
        struct.pack_into('<I', buf, 8, V4L2_MEMORY_MMAP)
        fcntl.ioctl(fd, VIDIOC_QUERYBUF, buf)
        length = struct.unpack_from('<I', buf, 20)[0]
        offset = struct.unpack_from('<I', buf, 32)[0]
        mm = mmap.mmap(fd, length, mmap.MAP_SHARED, mmap.PROT_READ|mmap.PROT_WRITE, offset=offset)
        buffers.append((mm, length))
        fcntl.ioctl(fd, VIDIOC_QBUF, buf)

    typ = ctypes.create_string_buffer(4)
    struct.pack_into('<I', typ, 0, V4L2_BUF_TYPE_VIDEO_CAPTURE)
    fcntl.ioctl(fd, VIDIOC_STREAMON, typ)
    return fd, buffers

def capture_loop(fd, buffers):
    global current_frame
    buf = ctypes.create_string_buffer(88)
    while True:
        try:
            struct.pack_into('<I', buf, 0, V4L2_BUF_TYPE_VIDEO_CAPTURE)
            struct.pack_into('<I', buf, 4, 0)
            struct.pack_into('<I', buf, 8, V4L2_MEMORY_MMAP)
            fcntl.ioctl(fd, VIDIOC_DQBUF, buf)
            idx = struct.unpack_from('<I', buf, 4)[0]
            used = struct.unpack_from('<I', buf, 20)[0]
            mm, _ = buffers[idx]
            mm.seek(0)
            data = mm.read(used)
            with frame_lock:
                current_frame = data
            fcntl.ioctl(fd, VIDIOC_QBUF, buf)
        except Exception:
            time.sleep(0.033)

def handle_client(conn):
    global current_frame
    try:
        req = conn.recv(1024).decode('utf-8', errors='ignore')
        if '?action=snapshot' in req:
            with frame_lock:
                frame = current_frame
            if frame:
                hdr = ('HTTP/1.1 200 OK\r\nContent-Type: image/jpeg\r\n'
                       f'Content-Length: {len(frame)}\r\nCache-Control: no-cache\r\n\r\n').encode()
                conn.sendall(hdr + frame)
        else:
            conn.sendall(b'HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=frame\r\nCache-Control: no-cache\r\n\r\n')
            while True:
                with frame_lock:
                    frame = current_frame
                if frame:
                    part = (f'--frame\r\nContent-Type: image/jpeg\r\nContent-Length: {len(frame)}\r\n\r\n').encode() + frame + b'\r\n'
                    conn.sendall(part)
                time.sleep(1.0 / FPS)
    except Exception:
        pass
    finally:
        conn.close()

def main():
    print(f'Starting MJPEG streamer on port {PORT}...')
    fd, buffers = setup_camera()
    threading.Thread(target=capture_loop, args=(fd, buffers), daemon=True).start()
    print(f'Camera initialized: {WIDTH}x{HEIGHT} @ {FPS}fps')

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(('0.0.0.0', PORT))
    srv.listen(10)
    print(f'Streaming on http://0.0.0.0:{PORT}/?action=stream')

    def shutdown(sig, frame):
        srv.close()
        sys.exit(0)
    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    while True:
        try:
            conn, _ = srv.accept()
            threading.Thread(target=handle_client, args=(conn,), daemon=True).start()
        except Exception:
            break

if __name__ == '__main__':
    main()
PYEOF

    # Disable cam_app at boot
    if [ -f "$CAM_APP_RC" ]; then
        mv "$CAM_APP_RC" "${CAM_APP_RC}.disabled"
        log_success "Disabled cam_app startup"
    fi

    # Stop cam_app if running
    CAM_PID=$(ps aux | grep cam_app | grep -v grep | awk '{print $1}')
    [ -n "$CAM_PID" ] && kill $CAM_PID 2>/dev/null && log_info "Stopped cam_app"
    sleep 2

    # Create startup script for MJPEG streamer
    cat > "$CAMERA_RC" << 'EOF'
#!/bin/sh /etc/rc.common
START=96
STOP=96
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command /usr/share/klippy-env/bin/python3 /mnt/UDISK/helper-script/mjpeg_streamer.py
    procd_set_param respawn
    procd_close_instance
}
EOF
    chmod +x "$CAMERA_RC"

    # Start it now
    python3 "$CAMERA_SCRIPT" &
    sleep 3

    mark_installed "camera_streamer"
    echo ""
    log_success "MJPEG Camera Streamer installed!"
    echo ""
    log_info "Stream URL:    http://$(hostname -I | awk '{print $1}'):8080/?action=stream"
    log_info "Snapshot URL:  http://$(hostname -I | awk '{print $1}'):8080/?action=snapshot"
    echo ""
    log_info "In Fluidd: Settings → Cameras → Add"
    log_info "  Type: MJPEG-Streamer"
    log_info "  Stream: http://<printer-ip>:4408/webcam/?action=stream"
    log_info "  Snapshot: http://<printer-ip>:4408/webcam/?action=snapshot"
    echo ""
    echo -e "${YELLOW}NOTE: Camera in Creality Print and touchscreen no longer works.${NC}"
    echo -e "${YELLOW}To restore: run helper script → Remove → Camera Streamer${NC}"
    echo ""
}

remove_camera() {
    echo ""
    log_info "Removing MJPEG Camera Streamer..."

    # Stop the streamer
    STREAM_PID=$(ps aux | grep mjpeg_streamer | grep -v grep | awk '{print $1}')
    [ -n "$STREAM_PID" ] && kill $STREAM_PID 2>/dev/null

    # Remove startup script
    rm -f "$CAMERA_RC"

    # Re-enable cam_app
    if [ -f "${CAM_APP_RC}.disabled" ]; then
        mv "${CAM_APP_RC}.disabled" "$CAM_APP_RC"
        log_success "Re-enabled cam_app startup"
        # Start it now
        $CAM_APP_RC start 2>/dev/null || true
    fi

    rm -f "$CAMERA_SCRIPT"
    mark_removed "camera_streamer"
    echo ""
    log_success "Camera Streamer removed. Creality Print camera restored."
    log_info "Reboot recommended to fully restore camera functionality."
    echo ""
}

case "$1" in
    install) install_camera ;;
    remove)  remove_camera ;;
    *)       echo "Usage: $0 [install|remove]" ;;
esac
