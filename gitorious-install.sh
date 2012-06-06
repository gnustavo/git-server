#!/bin/bash

# Copyright (C) 2012 by CPqD

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# http://www.dwheeler.com/essays/fixing-unix-linux-filenames.html
set -eu
IFS=`printf '\n\t'`

while getopts :nv OPT; do
    case $OPT in
	n|+n)
	
	    ;;
	v|+v)
	    set -x
	    ;;
	*)
	    echo "usage: `basename $0` [+-nv} [--] ARGS..."
	    exit 2
    esac
done
shift `expr $OPTIND - 1`

TMPDIR=`mktemp -d /tmp/tmp.XXXXXXXXXX` || exit 1
trap "rm -rf $TMPDIR" EXIT

source gitorious-install.config

# Pre-configure some packages
sudo apt-get install debconf-utils
sudo debconf-set-selections <<EOF
mysql-server-5.5 mysql-server/root_password_again password ${MYSQL_PWD}
mysql-server-5.5 mysql-server/root_password password ${MYSQL_PWD}
postfix postfix/mailname string ubuntu
postfix postfix/main_mailer_type select Internet Site
EOF

# Install needed packages
sudo apt-get -y install build-essential zlib1g-dev tcl-dev libexpat1-dev \
    libxslt1-dev libcurl4-openssl-dev postfix apache2 mysql-server mysql-client \
    apg geoip-bin libgeoip1 libgeoip-dev sqlite3 libsqlite3-dev imagemagick \
    libpcre3 libpcre3-dev zlib1g zlib1g-dev libyaml-dev libmysqlclient-dev \
    apache2-dev libonig-dev ruby-dev rubygems libruby libdbd-mysql-ruby \
    libmysql-ruby libmagick++-dev zip unzip memcached git git-svn git-doc \
    git-cvs ruby rake ruby-daemons ruby-rmagick stompserver \
    libapache2-mod-passenger ruby-bundler sphinxsearch

# Clone gitorious
git clone git://gitorious.org/gitorious/mainline.git ~/gitorious
cd ~/gitorious
git submodule init
git submodule update

# Put gitorious on the user's PATH
mkdir -p ~/bin
ln -s ~/gitorious/script/gitorious ~/bin
PATH=~/bin:$PATH

# Install boot scripts
cd ~/gitorious/doc/templates/ubuntu
BOOT_SCRIPTS='git-daemon git-poller git-ultrasphinx stomp'
sudo cp $BOOT_SCRIPTS /etc/init.d/
cd /etc/init.d
sudo chmod 755 $BOOT_SCRIPTS

# Create links needed by the boot scripts
sudo ln -s /usr /opt/ruby-enterprise
sudo ln -s ~/gitorious /var/www/gitorious

# Configure Apache2
cat >$TMPDIR/gitorious <<EOF
<VirtualHost *:80>
    ServerName ${HOSTNAME}
    DocumentRoot $HOME/gitorious/public
</VirtualHost>
EOF
sudo cp $TMPDIR/gitorious /etc/apache2/sites-available/

cat >$TMPDIR/gitorious-ssl <<EOF
<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        DocumentRoot $HOME/gitorious/public
        SSLEngine on
        SSLCertificateFile ${CERT_PEM}
        SSLCertificateKeyFile ${CERT_KEY}
        BrowserMatch ".*MSIE.*" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0
    </VirtualHost>
</IfModule>
EOF
sudo cp $TMPDIR/gitorious-ssl /etc/apache2/sites-available/

sudo a2dissite 000-default
sudo a2ensite gitorious gitorious-ssl
sudo service apache2 restart

# Create user gitorious in MySQL
mysql -u root -p"${MYSQL_PWD}" <<'EOF'
GRANT ALL PRIVILEGES ON *.* TO 'gitorious'@'localhost' IDENTIFIED BY '' WITH GRANT OPTION;
FLUSH PRIVILEGES;
QUIT
EOF

# Install all required gems
cd ~/gitorious
bundle install --path vendor/cache
bundle pack

# Create a few needed directories
cd ~
mkdir -p tmp/pids repositories tarballs tarballs-work

# Configure Gitorious
cd ~/gitorious/config

patch -o database.yml database.sample.yml <<EOF
--- database.sample.yml 2012-05-29 15:23:04.646180929 -0300
+++ database.yml        2012-06-03 17:15:33.144083791 -0300
@@ -34,6 +34,6 @@
   adapter: mysql
   database: gitorious_production
   username: root
-  password: 
+  password: ${MYSQL_PWD}
   host: localhost
   encoding: utf8
EOF

SECRET=`apg -m 64 | head -1`
patch -o gitorious.yml gitorious.sample.yml <<EOF
--- gitorious.sample.yml        2012-05-29 15:23:04.646180929 -0300
+++ gitorious.yml       2012-06-03 17:33:18.004126799 -0300
@@ -34,11 +34,11 @@
   gitorious_client_host: localhost
 
   # Host name users use to reach Gitorious, e.g. "gitorious.org".
-  gitorious_host: gitorious.test
+  gitorious_host: ${HOSTNAME}
 
   # The path where git repositories are stored. The actual (bare) repositories
   # reside in #{repository_base_path}/#{project.slug}/#{repository.name}.git/:
-  repository_base_path: "/var/git/repositories"
+  repository_base_path: "$HOME/repositories"
 
   # Gitorious allows users to download archived tarballs of repositories. In
   # order to do this, it needs a separate directory to do the rough work,
@@ -47,16 +47,16 @@
   #
   # Tarball cache directory. Gitorious uses X-Sendfile to deliver files to
   # users, so this needs to be readable by the web server.
-  archive_cache_dir: "/var/git/tarballs"
+  archive_cache_dir: "$HOME/tarballs"
 
   #
   # Temporary tarball work directory
-  archive_work_dir: "/var/git/tarballs-work"
+  archive_work_dir: "$HOME/tarballs-work"
 
   # Session key. It is recommended to use a long random string for this. A
   # suitable key can be generated with `apg -m 64`. Make sure you paste the
   # key as one long string, no newlines or escaped characters.
-  cookie_secret: ssssht
+  cookie_secret: ${SECRET}
 
   # --------------------
   # RECOMMENDED SETTINGS
@@ -76,7 +76,7 @@
 
   # If Gitorious trips on an unrecoverable error, it will send you an email
   # with details if you provide your addresses here.
-  exception_notification_emails:
+  exception_notification_emails: ${GITORIOUS_EMAIL}
 
   # Messaging queue configuration
   # Gitorious ships with two message queue implementations; Stomp via the
@@ -132,7 +132,7 @@
   # HTTP and git:// cloning. These protocols are anonymous, and will allow
   # unregistered users to pull repositories, given that they somehow obtained
   # the correct URLs.
-  #public_mode: true
+  public_mode: false
 
   # Enabling private repositories allows users to control read-access to their
   # repositories. Repositories are public by default, but individual users
@@ -140,7 +140,7 @@
   # from individual repositories and/or projects.
   # More information is available in the Gitorious Wiki:
   # https://gitorious.org/gitorious/pages/PrivateRepositories
-  #enable_private_repositories: false
+  enable_private_repositories: true
 
   # Only site admins can create projects.
   #only_site_admins_can_create_projects: false
@@ -241,7 +241,7 @@
   #extra_html_head_data:
 
   # Email address to the support for the Gitorious server
-  #gitorious_support_email: support@gitorious.local
+  #gitorious_support_email: ${ADMIN_EMAIL}
 
   # The SSH fingerprint of your server
   #ssh_fingerprint: "7e:af:8d:ec:f0:39:5e:ba:52:16:ce:19:fa:d4:b8:7d"
EOF

cp broker.yml.example broker.yml

# Fix a bug
cd ~/gitorious/config
patch boot.rb <<'EOF'
--- boot.rb.orig        2012-06-03 20:11:23.570703794 -0300
+++ boot.rb     2012-06-03 20:11:41.573698103 -0300
@@ -1,6 +1,8 @@
 # Don't change this file!
 # Configure your app in config/environment.rb and config/environments/*.rb
 
+require 'thread'
+
 RAILS_ROOT = "#{File.dirname(__FILE__)}/.." unless defined?(RAILS_ROOT)
 
 module Rails
EOF

# Substitute a deprecated configuration
patch ~/gitorious/config/ultrasphinx/production.conf <<'EOF'
--- production.conf.orig	2012-06-06 00:09:37.553350918 -0300
+++ production.conf	2012-06-06 00:09:47.849351147 -0300
@@ -10,7 +10,7 @@
   pid_file = /home/git/gitorious/db/sphinx/log/searchd.pid
   max_children = 300
   seamless_rotate = 1
-  address = 0.0.0.0
+  listen = 0.0.0.0
   read_timeout = 5
   max_matches = 100000
   query_log = /home/git/gitorious/db/sphinx/log/query.log
EOF

# Apply all configuration
cd ~/gitorious
export RAILS_ENV=production
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rake ultrasphinx:bootstrap

# Install crontab for the sphinx indexer
crontab -l >$TMPDIR/cron
echo '@hourly cd gitorious && RAILS_ENV=production bundle exec rake ultrasphinx:index' >>$TMPDIR/cron
crontab $TMPDIR/cron

# Create Gitorious's admin user
cd ~git/gitorious
RAILS_ENV=production ruby script/create_admin

# Fix some file permissions
cd ~git/gitorious
sudo chmod g+s log
sudo chgrp -R www-data log

