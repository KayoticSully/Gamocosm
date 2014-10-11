#!/bin/bash

set -e

yum -y update

yum -y install ruby nodejs gcc gcc-c++ curl-devel openssl-devel zlib-devel ruby-devel memcached git postgresql-server postgresql-contrib postgresql-devel tmux redis iptables-services

gem install passenger

passenger-install-nginx-module

wget -O /etc/systemd/system/nginx.service https://raw.githubusercontent.com/Gamocosm/Gamocosm/release/sysadmin/nginx.service
wget -O /etc/systemd/system/gamocosm-sidekiq.service https://raw.githubusercontent.com/Gamocosm/Gamocosm/release/sysadmin/sidekiq.service

sed -i "1s/^/user http;\\n/" /opt/nginx/conf/nginx.conf
sed -i "$ s/}/include \\/opt\\/nginx\\/sites-enabled\\/\\*.conf;\\n}/" /opt/nginx/conf/nginx.conf
sed -i "0,/listen[[:space:]]*80;/{s/80/8000/}" /opt/nginx/conf/nginx.conf

mkdir /opt/nginx/sites-enabled;
mkdir /opt/nginx/sites-available;

wget -O /opt/nginx/sites-available/gamocosm.conf https://raw.githubusercontent.com/Gamocosm/Gamocosm/release/sysadmin/nginx.conf
ln -s /opt/nginx/sites-available/gamocosm.conf /opt/nginx/sites-enabled/gamocosm.conf

systemctl enable nginx
systemctl enable memcached
systemctl enable redis
systemctl enable postgresql
systemctl enable gamocosm-sidekiq

postgresql-setup initdb

systemctl start postgresql
systemctl start redis
systemctl start memcached

echo "Run: createuser --createdb --pwprompt --superuser gamocosm"
echo "Run: psql"
echo "Run: \\password postgres"
echo "Run: \\q"
echo "Run: exit"
su - postgres

sed -i "/^# TYPE[[:space:]]*DATABASE[[:space:]]*USER[[:space:]]*ADDRESS[[:space:]]*METHOD/a local all gamocosm md5" /var/lib/pgsql/data/pg_hba.conf
systemctl restart postgresql

iptables -I INPUT -p tcp --dport 80 -j ACCEPT
systemctl mask firewalld.service
systemctl enable iptables.service
systemctl enable ip6tables.service
service iptables save

adduser -m http

echo "Run: ssh-keygen -t rsa"
echo "Note: set path to /home/http/.ssh/id_rsa-gamocosm"
echo "Run: exit"
su - http

mkdir /run/http
chown http:http /run/http

mkdir /var/www
cd /var/www
git clone https://github.com/Gamocosm/Gamocosm.git gamocosm
cd gamocosm
git checkout release
mkdir tmp
touch tmp/restart.txt
cp env.sh.template env.sh
chmod u+x env.sh
chown -R http:http .

sudo -u http gem install bundler
su - http -c "cd $(pwd) && bundle install --deployment"

read -p "Please fill in the information in env.sh (press any key to continue)"

vi env.sh
# no more sed -i "/SIDEKIQ_ADMIN_PASSWORD/ s/=.*$/=$SIDEKIQ_ADMIN_PASSWORD/" env.sh :(

su - http -c "cd $(pwd) && RAILS_ENV=production ./env.sh --bundler rake db:setup"

su - http -c "cd $(pwd) && RAILS_ENV=production ./env.sh --bundler rake assets:precompile"

OUTDOORS_IP_ADDRESS=$(ifconfig | grep -m 1 "inet" | awk "{ print \$2 }")
echo "$OUTDOORS_IP_ADDRESS gamocosm.com" >> /etc/hosts

systemctl start nginx
systemctl start gamocosm-sidekiq

echo "Done!"

# - scripts for: update, assets, restart
