#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "This script should run with sudo"
  exit 1
fi



wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh && sh /tmp/netdata-kickstart.sh --non-interactive



if ! sed -i 's/}$/    location \/stub_status {\n        stub_status;\n        allow 127.0.0.1;\n        deny all;\n    }\n}/' /etc/nginx/sites-available/site1 2>/dev/null; then
    echo "Nginx config file not found or sed failed!"
fi


mkdir -p /etc/netdata/go.d
cat << 'EOF' > /etc/netdata/go.d/nginx.conf
jobs:
  - name: site1_stats
    url: http://localhost:8081/stub_status
EOF



cat << 'EOF' >> /etc/netdata/netdata.conf

[global]

    update every = 3

    history = 7200


[plugin:proc]

    update every = 6


EOF



nginx -t && systemctl restart nginx

systemctl restart netdata

echo "DONE!"
