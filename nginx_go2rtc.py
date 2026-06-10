import subprocess

content = open('/etc/nginx/nginx.conf').read()

if 'go2rtc' in content:
    print('Nginx already configured')
    exit(0)

# go2rtc block for port 4408 (Fluidd) - insert before /webcam/ multiline
block_4408 = '''        location /go2rtc/ {
            proxy_pass http://127.0.0.1:1984/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $http_host;
            proxy_read_timeout 3600;
            proxy_send_timeout 3600;
        }
        location /go2rtc/api/ws {
            proxy_pass http://127.0.0.1:1984/api/ws?src=k2plus;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $http_host;
            proxy_read_timeout 3600;
            proxy_send_timeout 3600;
        }
        location /webcam/ {'''

# go2rtc block for port 4409 (Mainsail) - insert before /webcam/ single-line
block_4409 = '''        location /go2rtc/ {
            proxy_pass http://127.0.0.1:1984/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $http_host;
            proxy_read_timeout 3600;
            proxy_send_timeout 3600;
        }
        location /go2rtc/api/ws {
            proxy_pass http://127.0.0.1:1984/api/ws?src=k2plus&$args;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $http_host;
            proxy_read_timeout 3600;
            proxy_send_timeout 3600;
        }
        location /webcam/  { proxy_pass http://mjpgstreamer1/; }'''

# Replace in 4408 block
old_4408 = '        location /webcam/ {\n            proxy_pass http://mjpgstreamer1/;\n        }'
content = content.replace(old_4408, block_4408 + '\n            proxy_pass http://mjpgstreamer1/;\n        }', 1)

# Replace in 4409 block  
old_4409 = '        location /webcam/  { proxy_pass http://mjpgstreamer1/; }'
content = content.replace(old_4409, block_4409, 1)

# Write and test
open('/etc/nginx/nginx.conf', 'w').write(content)
result = subprocess.run(['nginx', '-t'], capture_output=True, text=True)
if result.returncode == 0:
    print('Nginx updated for Fluidd and Mainsail')
else:
    print('ERROR:', result.stderr)
    # Restore backup
    import shutil
    shutil.copy('/mnt/UDISK/helper-script/.nginx.conf.bak', '/etc/nginx/nginx.conf')
    print('Restored backup!')
