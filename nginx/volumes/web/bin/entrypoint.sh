#!/bin/sh

# Check if SSL should be enabled (if certificates exists)
if [ -f "/cert/cert.pem" -a -f "/cert/key-no-password.pem" ]; then
  echo "found certificate and key, linking ssl config"
  ssl="-ssl"
else
  echo "linking plain config"
fi

unlink /etc/nginx/conf.d/mattermost.conf

if [ -f "/etc/nginx/conf.d/mattermost.conf" ]; then
  echo "Found config file /etc/nginx/conf.d/mattermost.conf"
  rm -rf /etc/nginx/conf.d/mattermost.conf
else
  echo "No config file /etc/nginx/conf.d/mattermost.conf"
fi

# Linking Nginx configuration file
ln -s /etc/nginx/sites-available/mattermost$ssl /etc/nginx/conf.d/mattermost.conf

# Setup app host and port on configuration file
echo "MATTERMOST HOST: ${APP_HOST}"
echo "MATTERMOST PORT: ${APP_PORT_NUMBER}"

sed -i "s/{%APP_HOST%}/${APP_HOST}/g" /etc/nginx/conf.d/mattermost.conf
sed -i "s/{%APP_PORT%}/${APP_PORT_NUMBER}/g" /etc/nginx/conf.d/mattermost.conf

# Run Nginx
nginx -g 'daemon off;'
