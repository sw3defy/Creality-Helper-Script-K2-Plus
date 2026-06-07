#!/usr/bin/env python3
import urllib.request, json, time

def reconnect():
    try:
        urllib.request.urlopen('http://127.0.0.1:1984/api/streams?src=k2plus', timeout=10)
        print('Stream reconnected', flush=True)
    except Exception as e:
        print('Reconnect error:', e, flush=True)

print('Camera watchdog started', flush=True)

while True:
    try:
        r = urllib.request.urlopen('http://127.0.0.1:1984/api/streams', timeout=3)
        data = json.loads(r.read())
        producers = data.get('k2plus', {}).get('producers', [])
        if not producers:
            print('No producers - reconnecting...', flush=True)
            reconnect()
    except Exception as e:
        print('Watchdog error:', e, flush=True)
        reconnect()
    time.sleep(30)
