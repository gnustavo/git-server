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

if [ "$#" -eq 1 ]; then
    CONFIG="$1"
else
    echo >&2 "usage: $0 CONFIGFILE"
    exit 1
fi

TMPDIR=`mktemp -d /tmp/tmp.XXXXXXXXXX` || exit 1
trap "rm -rf $TMPDIR" EXIT

set -x

# Grok configuration
source "$CONFIG"

# Check if all config variable are set
cat >/dev/null <<EOF
${EMAIL_TO}
${ERROR_EMAIL_FROM}
${APP_EMAIL_FROM}
${SMTP_SERVER}
${SMTP_USERNAME}
${SMTP_PASSWORD}
${SMTP_PORT}
${ISSUE_PAT}
${ISSUE_SERVER_LINK}
${REPOS_DIR}
${RC_ADMIN}
${RC_PWD}
EOF

# Create the git users SSH directory if it doesn't already exist
cd ~
if [ ! -e .ssh ]; then
    mkdir .ssh && chmod 700 .ssh
fi

# Install needed packages
sudo apt-get -y install python-virtualenv python-ldap libsasl2-dev git python-dev apache2 

# Set up git
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
git config --global color.ui true

# Setup virtual environment for Python
virtualenv ~/venv
set +u
source venv/bin/activate
set -u

# Install RhodeCode
mkdir ~/rhodecode
cd ~/rhodecode
easy_install rhodecode

# TODO: Install rabbitmq

# Configure RhodeCode
cd ~/rhodecode
paster make-config RhodeCode production.ini
patch production.ini <<EOF
--- production.ini.orig 2012-05-29 10:42:14.197177952 -0300
+++ production.ini.new  2012-05-29 10:50:12.205185304 -0300
@@ -13,13 +13,13 @@
 ## any error reports after application crash                                  ##
 ## Additionally those settings will be used by RhodeCode mailing system       ##
 ################################################################################
-#email_to = admin@localhost
-#error_email_from = paste_error@localhost
-#app_email_from = rhodecode-noreply@localhost
+email_to = ${EMAIL_TO}
+error_email_from = ${ERROR_EMAIL_FROM}
+app_email_from = ${APP_EMAIL_FROM}
 #error_message =
-#email_prefix = [RhodeCode]
+email_prefix = [RhodeCode]
 
-#smtp_server = mail.server.com
+smtp_server = ${SMTP_SERVER}
 #smtp_username = 
 #smtp_password = 
 #smtp_port = 
@@ -57,6 +57,7 @@
 container_auth_enabled = false
 proxypass_auth_enabled = false
 default_encoding = utf8
+filter-with = proxy-prefix

 ## overwrite schema of clone url
 ## available vars:
@@ -75,12 +75,12 @@
 ## default one used here is # with a regex passive group for `#`
 ## {id} will be all groups matched from this pattern
 
-issue_pat = (?:\s*#)(\d+)
+issue_pat = ${ISSUE_PAT}
 
 ## server url to the issue, each {id} will be replaced with match
 ## fetched from the regex and {repo} is replaced with repository name
 
-issue_server_link = https://myissueserver.com/{repo}/issue/{id}
+issue_server_link = ${ISSUE_SERVER_LINK}
 
 ## prefix to add to link to indicate it's an url
 ## #314 will be replaced by 
@@ -314,3 +315,8 @@
 class=rhodecode.lib.colored_formatter.ColorFormatterSql
 format= %(asctime)s.%(msecs)03d %(levelname)-5.5s [%(name)s] %(message)s
 datefmt = %Y-%m-%d %H:%M:%S
+
+[filter:proxy-prefix]
+use = egg:PasteDeploy#prefix
+prefix = /rhodecode
+
EOF

# Create directories for repos
mkdir -p "$REPOS_DIR"

# Setup Rhodecode
cd ~/rhodecode
echo y | paster setup-rhodecode \
    --user="$RC_ADMIN" \
    --password="$RC_PWD" \
    --email="$EMAIL_TO" \
    --repos="$REPOS_DIR" \
    production.ini

# Based on: https://bitbucket.org/marcinkuzminski/rhodecode/raw/2dc4cfa44b25/init.d/rhodecode-daemon2
cat >$TMPDIR/rhodecode <<'EOF'
#!/bin/sh -e
########################################
#### THIS IS A DEBIAN INIT.D SCRIPT ####
########################################

### BEGIN INIT INFO
# Provides:          rhodecode          
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts instance of rhodecode
# Description:       starts instance of rhodecode using start-stop-daemon
### END INIT INFO

APP_NAME="rhodecode"
APP_HOMEDIR="git"
APP_PATH="/home/$APP_HOMEDIR/$APP_NAME"

CONF_NAME="production.ini"

PID_PATH="$APP_PATH/$APP_NAME.pid"
LOG_PATH="$APP_PATH/$APP_NAME.log"

PYTHON_PATH="/home/$APP_HOMEDIR/venv"

RUN_AS="git"

DAEMON="$PYTHON_PATH/bin/paster"

DAEMON_OPTS="serve --daemon \
  --user=$RUN_AS \
  --group=$RUN_AS \
  --pid-file=$PID_PATH \
  --log-file=$LOG_PATH  $APP_PATH/$CONF_NAME"


start() {
  echo "Starting $APP_NAME"
  PYTHON_EGG_CACHE="/tmp" HOME=/home/$APP_HOMEDIR start-stop-daemon -d $APP_PATH \
      --start --quiet \
      --pidfile $PID_PATH \
      --user $RUN_AS \
      --exec $DAEMON -- $DAEMON_OPTS
}

stop() {
  echo "Stopping $APP_NAME"
  start-stop-daemon -d $APP_PATH \
      --stop --quiet \
      --pidfile $PID_PATH || echo "$APP_NAME - Not running!"
  
  if [ -f $PID_PATH ]; then
    rm $PID_PATH
  fi
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    echo "Restarting $APP_NAME"
    ### stop ###
    stop
    wait
    ### start ###
    start
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
esac
EOF
sudo cp $TMPDIR/rhodecode /etc/init.d
sudo chmod 755 /etc/init.d/rhodecode
sudo update-rc.d rhodecode defaults

# Make git the default repository type
patch venv/lib/python*/site-packages/RhodeCode*.egg/rhodecode/templates/admin/repos/repo_add_base.html <<'EOF'
--- ./templates/admin/repos/repo_add_base.html.orig     2012-06-10 12:17:31.469484793 -0300
+++ ./templates/admin/repos/repo_add_base.html  2012-06-10 12:17:47.909470152 -0300
@@ -38,7 +38,7 @@
                 <label for="repo_type">${_('Type')}:</label>
             </div>
             <div class="input">
-                ${h.select('repo_type','hg',c.backends,class_="small")}
+                ${h.select('repo_type','git',c.backends,class_="small")}
                 <span class="help-block">${_('Type of repository to create.')}</span>
             </div>
          </div>
EOF

# Enable needed Apache modules
sudo a2enmod proxy_http rewrite ssl headers

# Change Apache configuration for SSL Virtual Hosts.
sudo patch /etc/apache2/ports.conf <<'EOF'
--- ports.conf.orig     2012-06-10 18:16:29.097552822 -0300
+++ ports.conf  2012-06-10 18:16:52.385551176 -0300
@@ -14,6 +14,7 @@
     # to <VirtualHost *:443>
     # Server Name Indication for SSL named virtual hosts is currently not
     # supported by MSIE on Windows XP.
+    NameVirtualHost *:443
     Listen 443
 </IfModule>

EOF

sudo patch /etc/apache2/sites-available/default-ssl <<'EOF'
--- default-ssl.orig    2012-06-10 19:09:01.693695635 -0300
+++ default-ssl 2012-06-10 19:09:10.973694566 -0300
@@ -1,5 +1,5 @@
 <IfModule mod_ssl.c>
-<VirtualHost _default_:443>
+<VirtualHost *:443>
        ServerAdmin webmaster@localhost

        DocumentRoot /var/www
EOF

# Create and enable VirtualHosts for git
cat >$TMPDIR/git <<EOF
<VirtualHost *:80>
    ServerName ${SERVERNAME}

    RewriteEngine On
    RewriteRule ^/(.*) https://${SERVERNAME}/\$1 [R,L]
</VirtualHost>
EOF
sudo cp $TMPDIR/git /etc/apache2/sites-available/

cat >$TMPDIR/git-ssl <<EOF
<IfModule mod_ssl.c>
    <VirtualHost *:443>
        ServerName ${SERVERNAME}
        SSLEngine on
        SSLCertificateFile ${CERT_PEM}
        SSLCertificateKeyFile ${CERT_KEY}
        BrowserMatch ".*MSIE.*" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0

        AuthType Basic
        AuthName "Git authentication"
        AuthUserFile /etc/apache2/.htpasswd
        require valid-user

        RequestHeader unset X-Forwarded-User

        RewriteEngine On
        RewriteRule ^/$ /rhodecode [R,L]
        RewriteCond %{LA-U:REMOTE_USER} (.+)
        RewriteRule .* - [E=RU:%1]

        RequestHeader set X-Forwarded-User %{RU}e

        <Proxy *>
            Order allow,deny
            Allow from all
        </Proxy>

        ProxyPreserveHost On

        <Location /rhodecode>
            ProxyPass        http://127.0.0.1:5000/rhodecode
            ProxyPassReverse http://127.0.0.1:5000/rhodecode
        </Location>
    </VirtualHost>
</IfModule>
EOF
sudo cp $TMPDIR/git-ssl /etc/apache2/sites-available/

sudo a2ensite git git-ssl

# TODO: LDAP integration