#!/usr/bin/env python3
import urllib.request, json, time

def check_stream():
    try:
        r = urllib.request.urlopen('http://127.0.0.1:1984/api/streams', timeout=3)
        data = json.loads(r.read())
        stream = data.get('k2plus', {})
        producers = stream.get('producers', [])
        if not producers:
            return False
        bytes_recv = producers[0].get('bytes_recv', 0)
        return bytes_recv > 0
    except:
        return False

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
        stream = data.get('k2plus', {})
        producers = stream.get('producers', [])
        
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
