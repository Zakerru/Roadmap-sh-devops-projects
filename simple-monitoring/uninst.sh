#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "This script should run with sudo"
  exit 1
fi

sed -i '/location \/stub_status {/,/}/d' /etc/nginx/sites-available/site1

if [ -f "/tmp/netdata-kickstart.sh" ]; then
    sh /tmp/netdata-kickstart.sh --uninstall --non-interactive
fi

rm -rf /etc/netdata
rm -rf /var/lib/netdata
rm -rf /var/log/netdata

apt remove -y stress apache2-utils
apt autoremove -y

nginx -t && systemctl restart nginx

echo "DONE!"
