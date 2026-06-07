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
            data=payload,
            method='POST',
            headers={'Content-Type': 'plain/text'}
        )
        try:
            r = urllib.request.urlopen(req, timeout=10)
            response = r.read()
            decoded = base64.b64decode(response)
            data = json.loads(decoded)
            answer_sdp = data['sdp'].encode()
            
            # Small delay to let go2rtc prepare
            time.sleep(0.1)
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/sdp')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Content-Length', len(answer_sdp))
            self.end_headers()
            self.wfile.write(answer_sdp)
            print(f'Success! Bridge connected', flush=True)
        except Exception as e:
            print(f'Error: {e}', flush=True)
            self.send_response(500)
            self.end_headers()
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.end_headers()


import threading, time

server = http.server.HTTPServer(('127.0.0.1', 8090), K2Handler)
print('K2 bridge running on 8090', flush=True)
server.serve_forever()
