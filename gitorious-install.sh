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

TMPDIR=`mktemp -d /tmp/tmp.XXXXXXXXXX` || exit 1
trap "rm -rf $TMPDIR" EXIT

# Check environment
if [ `id -run` != git ]; then
    echo "ERROR: You should run me as user 'git', not '`id -run`'." >&2
    exit 1
fi

DISTRIB_OK='Ubuntu 12.04 LTS'
source /etc/lsb-release
if [ "$DISTRIB_DESCRIPTION" != "$DISTRIB_OK" ]; then
    echo "ERROR: I'm prepared to run on '$DISTRIB_OK', not on '$DISTRIB_DESCRIPTION'." >&2
    exit 1
fi

set -x

# Grok configuration
source gitorious-install.config

# Pre-configure some packages to avoid manual intervention
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

# Put gitorious in the user's PATH
mkdir -p ~/bin
ln -s ~/gitorious/script/gitorious ~/bin
PATH=~/bin:$PATH

# Disable default stompserver boot script
sudo service stompserver stop
sudo update-rc.d -f stompserver remove
sudo update-rc.d stompserver stop 20 0 1 2 3 4 5 6 .

# Install boot scripts
cd ~/gitorious/doc/templates/ubuntu

sudo patch -o /etc/init.d/git-daemon <<EOF
--- git-daemon  2012-06-05 23:07:48.484013139 -0300
+++ /etc/init.d/git-daemon      2012-06-06 10:00:17.105643453 -0300
@@ -11,11 +11,11 @@
 
 # Author: Fabio Akita <fabioakita@gmail.com>
 
-RUBY_HOME="/opt/ruby-enterprise"
-GITORIOUS_HOME="/var/www/gitorious"
+RUBY_HOME="/usr"
+GITORIOUS_HOME="$HOME/gitorious"
 RETVAL=0
 PROG="git-daemon"
-GIT_DAEMON="\$RUBY_HOME/bin/ruby \$GITORIOUS_HOME/script/git-daemon -d"
+GIT_DAEMON="bundle exec \$RUBY_HOME/bin/ruby \$GITORIOUS_HOME/script/git-daemon -d"
 LOCK_FILE=/var/lock/git-daemon
 PID_FILE=\$GITORIOUS_HOME/log/git-daemon.pid
  
@@ -36,7 +36,7 @@
   do_check_pid
   if [ \$RUNNING != 2 ] ; then
     echo -n "Starting \$PROG: "
-    /bin/su - git -c "\$GIT_DAEMON"
+    /bin/su - git -c "cd \$GITORIOUS_HOME && \$GIT_DAEMON"
     sleep 5
     if [ -f \$PID_FILE ] ; then
       echo "success"
EOF

sudo patch -o /etc/init.d/git-poller <<EOF
--- git-poller  2012-06-05 23:07:48.484013139 -0300
+++ /etc/init.d/git-poller      2012-06-06 10:09:43.385624623 -0300
@@ -11,11 +11,11 @@
 
 # Author: Antonio Marques <acmarques@gmail.com>
 
-RUBY_HOME="/opt/ruby-enterprise"
-GITORIOUS_HOME="/var/www/gitorious"
+RUBY_HOME="/usr"
+GITORIOUS_HOME="$HOME/gitorious"
 RETVAL=0
 PROG="poller"
-GIT_POLLER="\$RUBY_HOME/bin/ruby \$GITORIOUS_HOME/script/poller"
+GIT_POLLER="bundle exec \$RUBY_HOME/bin/ruby \$GITORIOUS_HOME/script/poller"
 LOCK_FILE=/var/lock/git-poller
 PID_FILE=\$GITORIOUS_HOME/tmp/pids/poller0.pid
 export RAILS_ENV=production
@@ -40,7 +40,7 @@
   do_check_pid
   if [ \$RUNNING != 2 ] ; then
     echo -n "Starting \$PROG: "
-    /bin/su - git -c "RAILS_ENV=\$RAILS_ENV \$GIT_POLLER start"
+    /bin/su - git -c "cd \$GITORIOUS_HOME && RAILS_ENV=\$RAILS_ENV \$GIT_POLLER start"
     sleep 4
     if [ -f \$PID_FILE ] ; then
       echo "Success"
@@ -66,7 +66,7 @@
     RETVAL=1
   else
     #killproc -p \$PID_FILE
-    /bin/su - git -c "RAILS_ENV=\$RAILS_ENV \$GIT_POLLER stop"
+    /bin/su - git -c "cd \$GITORIOUS_HOME && RAILS_ENV=\$RAILS_ENV \$GIT_POLLER stop"
     RETVAL=\$?
     sleep 4
   fi
EOF

sudo patch -o /etc/init.d/git-ultrasphinx <<EOF
--- git-ultrasphinx     2012-06-05 23:07:48.484013139 -0300
+++ /etc/init.d/git-ultrasphinx 2012-06-06 10:17:54.969608274 -0300
@@ -11,12 +11,12 @@
 
 # Author: Fabio Akita <fabioakita@gmail.com>
 
-GITORIOUS_HOME="/var/www/gitorious"
+GITORIOUS_HOME="$HOME/gitorious"
 RETVAL=0
-START_CMD="cd \$GITORIOUS_HOME && rake ultrasphinx:daemon:start RAILS_ENV=production"
-STOP_CMD="cd \$GITORIOUS_HOME && rake ultrasphinx:daemon:stop RAILS_ENV=production"
-RESTART_CMD="cd \$GITORIOUS_HOME && rake ultrasphinx:daemon:restart RAILS_ENV=production"
-STATUS_CMD="cd \$GITORIOUS_HOME && rake ultrasphinx:daemon:status RAILS_ENV=production"
+START_CMD="cd \$GITORIOUS_HOME && bundle exec rake ultrasphinx:daemon:start RAILS_ENV=production"
+STOP_CMD="cd \$GITORIOUS_HOME && bundle exec rake ultrasphinx:daemon:stop RAILS_ENV=production"
+RESTART_CMD="cd \$GITORIOUS_HOME && bundle exec rake ultrasphinx:daemon:restart RAILS_ENV=production"
+STATUS_CMD="cd \$GITORIOUS_HOME && bundle exec rake ultrasphinx:daemon:status RAILS_ENV=production"
 LOCK_FILE=/var/lock/git-ultrasphinx
 PID_FILE=\$GITORIOUS_HOME/db/sphinx/log/searchd.pid
  
EOF

sudo patch -o /etc/init.d/stomp <<EOF
--- stomp       2012-06-05 23:07:48.484013139 -0300
+++ /etc/init.d/stomp   2012-06-06 10:26:05.685591956 -0300
@@ -10,12 +10,12 @@
 ### END INIT INFO
 #
 
-RUBY_HOME="/opt/ruby-enterprise"
+RUBY_HOME="/usr"
 GEMS_HOME="/usr"
-GITORIOUS_HOME="/var/www/gitorious"
+GITORIOUS_HOME="$HOME/gitorious"
 RETVAL=0
 PROG="stompserver"
-STOMP="\$RUBY_HOME/bin/ruby \$GEMS_HOME/bin/stompserver -w \$GITORIOUS_HOME/tmp/stomp -q file -s queue &> /dev/null &"
+STOMP="bundle exec \$RUBY_HOME/bin/ruby \$GEMS_HOME/bin/stompserver -w \$GITORIOUS_HOME/tmp/stomp -q file -s queue &> /dev/null &"
 LOCK_FILE=/var/lock/stomp
 PID_FILE=\$GITORIOUS_HOME/tmp/stomp/log/stompserver.pid
 
@@ -39,7 +39,7 @@
   do_check_pid
   if [ \$RUNNING != 2 ] ; then
     echo -n "Starting \$PROG: "
-    /bin/su - git -c "\$STOMP"
+    /bin/su - git -c "cd \$GITORIOUS_HOME && \$STOMP"
     sleep 4
     if [ -f \$PID_FILE ] ; then
       echo "Success"
EOF

for i in git-daemon git-poller git-ultrasphinx stomp; do
    sudo chmod 755 /etc/init.d/$i
    sudo update-rc.d $i defaults
done

# Configure Apache2
cat >$TMPDIR/gitorious <<EOF
<VirtualHost *:80>
    ServerName ${SERVERNAME}
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
sudo a2enmod ssl
sudo service apache2 restart

# Create user gitorious in MySQL
mysql -u root -p"${MYSQL_PWD}" <<'EOF'
GRANT ALL PRIVILEGES ON *.* TO 'gitorious'@'localhost' IDENTIFIED BY '' WITH GRANT OPTION;
FLUSH PRIVILEGES;
QUIT
EOF

# Install all required Ruby gems
cd ~/gitorious
bundle install --path vendor/cache
bundle pack

# Create a few needed directories
cd ~
mkdir -p gitorious/tmp/pids repositories tarballs tarballs-work

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
+  gitorious_host: ${SERVERNAME}
 
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
   # suitable key can be generated with \`apg -m 64\`. Make sure you paste the
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
@@ -140,10 +140,10 @@
   # from individual repositories and/or projects.
   # More information is available in the Gitorious Wiki:
   # https://gitorious.org/gitorious/pages/PrivateRepositories
-  #enable_private_repositories: false
+  enable_private_repositories: true
 
   # Only site admins can create projects.
-  #only_site_admins_can_create_projects: false
+  only_site_admins_can_create_projects: true
 
   # System message that will appear on all pages if present
   #system_message:
@@ -167,10 +167,10 @@
   #always_display_ssh_url: false
 
   # Is this gitorious.org? Read: should we have a very flashy homepage?
-  #is_gitorious_dot_org: true
+  is_gitorious_dot_org: false
 
   # Configure which address to use as From when sending email
-  #sender_email_address: "Gitorious <no-reply@yourdomain.example>"
+  sender_email_address: "Gitorious <gustavo+gitoriousadmin@cpqd.com.br>"
 
   # Mangle visible e-mail addresses (spam protection)
   #mangle_email_addresses: true
@@ -231,7 +231,7 @@
   #
 
   # Pick a default license
-  #default_license: GNU Affero General Public License (AGPLv3)
+  default_license: None
 
   # ----------------
   # THEMING SETTINGS
@@ -241,7 +241,7 @@
   #extra_html_head_data:
 
   # Email address to the support for the Gitorious server
-  #gitorious_support_email: support@gitorious.local
+  gitorious_support_email: ${ADMIN_EMAIL}
 
   # The SSH fingerprint of your server
   #ssh_fingerprint: "7e:af:8d:ec:f0:39:5e:ba:52:16:ce:19:fa:d4:b8:7d"
@@ -251,6 +251,7 @@
   #additional_footer_links:
   #  - - Professional Gitorious Services
   #    - http://gitorious.com/
+  additional_footer_links:
 
   # Set to true if you want to render terms of service and privacy policy links
   # in the footer.
EOF

cp broker.yml.example broker.yml

# Fix a bug in Gitorious
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

# Fix an annoying use of a deprecated method in the system Ruby
sudo patch /usr/lib/ruby/vendor_ruby/1.8/rubygems/source_index.rb <<'EOF'
--- source_index.rb.orig 2012-06-06 09:41:59.709679944 -0300
+++ source_index.rb      2012-06-06 09:40:39.801682601 -0300
@@ -124,7 +124,7 @@
         gemspec = Gem::Deprecate.skip_during do
           Gem::Specification.load spec_file
         end
-        add_spec gemspec if gemspec
+        Gem::Specification.add_spec gemspec if gemspec
       end
     end
 
EOF

# Apply all configuration
cd ~/gitorious
export RAILS_ENV=production
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rake ultrasphinx:bootstrap

# Substitute a deprecated configuration in Gitorious
ed ~/gitorious/config/ultrasphinx/production.conf <<EOF
/address =/
s/address/listen/
i
  compat_sphinxql_magics = 0
.
w
q
EOF

# Install crontab for the sphinx indexer
crontab -l >$TMPDIR/cron || true
echo '@hourly cd gitorious && RAILS_ENV=production bundle exec rake ultrasphinx:index' >>$TMPDIR/cron
crontab $TMPDIR/cron

# Create Gitorious's admin user
cd ~git/gitorious
RAILS_ENV=production ruby script/create_admin

# Fix some file permissions
cd ~git/gitorious
sudo chmod g+s log
sudo chgrp -R www-data log

