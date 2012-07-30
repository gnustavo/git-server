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

IDIR=`dirname $0`
source "$IDIR"/server.conf
source "$IDIR"/prelude.sh

# Check if all config variables are set
cat >/dev/null <<EOF
${EMAIL_TO}
${ERROR_EMAIL_FROM}
${APP_EMAIL_FROM}
${SMTP_SERVER}
${ISSUE_PAT}
${ISSUE_SERVER_LINK}
${REPOS_DIR}
${RC_ADMIN}
${RC_PWD}
${RMQ_USER}
${RMQ_PASS}
EOF

# Setup virtual environment for Python
virtualenv --no-site-packages ~/venv
set +u
source ~/venv/bin/activate
set -u

# Install RhodeCode
mkdir -p ~/rhodecode
(cd ~/rhodecode; easy_install https://secure.rhodecode.org/rhodecode/archive/beta.zip python_ldap waitress)

# Configure RabbitMQ
if sudo rabbitmqctl list_vhosts | grep -q rhodevhost; then
    : rabbitmqctl is already configured
else
    sudo rabbitmqctl add_user ${RMQ_USER} ${RMQ_PASS}
    sudo rabbitmqctl add_vhost rhodevhost
    sudo rabbitmqctl set_permissions -p rhodevhost ${RMQ_USER} ".*" ".*" ".*"
fi

# Configure RhodeCode
(cd ~/rhodecode; paster make-config RhodeCode production.ini)

patch ~/rhodecode/production.ini <<EOF
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
@@ -84,13 +84,13 @@
 ## default one used here is #<numbers> with a regex passive group for `#`
 ## {id} will be all groups matched from this pattern
 
-issue_pat = (?:\s*#)(\d+)
+issue_pat = ${ISSUE_PAT}
 
 ## server url to the issue, each {id} will be replaced with match
 ## fetched from the regex and {repo} is replaced with full repository name
 ## including groups {repo_name} is replaced with just name of repo
 
-issue_server_link = https://myissueserver.com/{repo}/issue/{id}
+issue_server_link = ${ISSUE_SERVER_LINK}
 
 ## prefix to add to link to indicate it's an url
 ## #314 will be replaced by <issue_prefix><id>
@@ -111,12 +111,12 @@
 ####################################
 ###        CELERY CONFIG        ####
 ####################################
-use_celery = false
+use_celery = true
 broker.host = localhost
-broker.vhost = rabbitmqhost
+broker.vhost = rhodevhost
 broker.port = 5672
-broker.user = rabbitmq
-broker.password = qweqwe
+broker.user = ${RMQ_USER}
+broker.password = ${RMQ_PASS}
 
 celery.imports = rhodecode.lib.celerylib.tasks

EOF

# Create directories for repos
mkdir -p "$REPOS_DIR"

# Setup Rhodecode
echo y | (cd ~/rhodecode; paster setup-rhodecode \
    --user="$RC_ADMIN" \
    --password="$RC_PWD" \
    --email="$EMAIL_TO" \
    --repos="$REPOS_DIR" \
    production.ini)

# Configure filter prefix
(cd ~/rhodecode; patch production.ini) <<'EOF'
--- production.ini.1    2012-06-12 21:52:18.522894535 -0300
+++ production.ini      2012-06-12 21:52:12.603931008 -0300
@@ -66,6 +66,7 @@
 container_auth_enabled = false
 proxypass_auth_enabled = false
 default_encoding = utf8
+filter-with = proxy-prefix

 ## overwrite schema of clone url
 ## available vars:
@@ -329,3 +329,8 @@
 class=rhodecode.lib.colored_formatter.ColorFormatterSql
 format= %(asctime)s.%(msecs)03d %(levelname)-5.5s [%(name)s] %(message)s
 datefmt = %Y-%m-%d %H:%M:%S
+
+[filter:proxy-prefix]
+use = egg:PasteDeploy#prefix
+prefix = /r
+
EOF

# Based on: https://gist.github.com/2866413#file_rhodecode_init.d.sh
cat >$TMPDIR/rhodecode <<'EOF'
#!/bin/sh

### BEGIN INIT INFO
# Provides:       rhodecode
# Required-Start: $all
# Required-Stop:  $all
# Default-Start:  2 3 4 5
# Default-Stop:   0 1 6
# Short-Description: Starts RhodeCode
### END INIT INFO

USER=git
PATH=/home/$USER/bin:$PATH

VENV_DIR=/home/git/venv
DATA_DIR=/home/git/rhodecode

CELERY_ARGS="$VENV_DIR/bin/paster celeryd $DATA_DIR/production.ini"
RHODECODE_ARGS="$VENV_DIR/bin/paster serve $DATA_DIR/production.ini"

CELERY_PID_FILE=/var/run/celeryd.pid
RHODECODE_PID_FILE=/var/run/rhodecode.pid

start_celery() {
    /sbin/start-stop-daemon \
        --start \
        --background \
        --chuid $USER \
        --pidfile $CELERY_PID_FILE \
        --make-pidfile \
        --exec $VENV_DIR/bin/python -- $CELERY_ARGS
}

start_rhodecode() {
    /sbin/start-stop-daemon \
        --start \
        --background \
        --chuid $USER \
        --pidfile $RHODECODE_PID_FILE \
        --make-pidfile \
        --exec $VENV_DIR/bin/python -- $RHODECODE_ARGS
}

stop_rhodecode() {
    /sbin/start-stop-daemon \
        --stop \
        --user $USER \
        --pidfile $RHODECODE_PID_FILE
}

stop_celery() {
    /sbin/start-stop-daemon \
        --stop \
        --user $USER \
        --pidfile $CELERY_PID_FILE
}

case "$1" in
    start)
        echo "Starting Celery"
        start_celery
        echo "Starting RhodeCode"
        start_rhodecode
        ;;
    start_celery)
        echo "Starting Celery"
        start_celery
        ;;
    start_rhodecode)
        echo "Starting RhodeCode"
        start_rhodecode
        ;;
    stop)
        echo "Stopping RhodeCode"
        stop_rhodecode
        echo "Stopping Celery"
        stop_celery
        ;;
    stop_rhodecode)
        echo "Stopping RhodeCode"
        stop_rhodecode
        ;;
    stop_celery)
        echo "Stopping Celery"
        stop_celery
        ;;
    restart)
        echo "Stopping RhodeCode and Celery"
        stop
        echo "Starting Celery"
        start_celery
        echo "Starting RhodeCode"
        start_rhodecode
        ;;
    *)
        echo "Usage: ./rhodecode {start|stop|restart|start_celery|stop_celery|start_rhodecode|stop_rhodecode}"
        exit 2
        ;;
esac

exit 0
EOF
sudo cp $TMPDIR/rhodecode /etc/init.d
sudo chmod 755 /etc/init.d/rhodecode
sudo update-rc.d rhodecode defaults

# Make git the default repository type
sed -i.original -e "s/'hg'/'git'/" ~/venv/lib/python*/site-packages/RhodeCode*.egg/rhodecode/templates/admin/repos/repo_add_base.html

# Disable Mercurial
sed -i.original -e "s/'hg'/#&/" ~/venv/lib/python*/site-packages/RhodeCode*.egg/rhodecode/__init__.py

# Enable needed Apache modules
sudo a2enmod proxy_http rewrite ssl headers

# Change Apache configuration for SSL Virtual Hosts.
if grep -q PaTcHeD /etc/apache2/ports.conf; then
    : /etc/apache2/ports.conf is already patched
else
    sudo patch /etc/apache2/ports.conf <<'EOF'
--- ports.conf.orig     2012-06-10 18:16:29.097552822 -0300
+++ ports.conf  2012-06-10 18:16:52.385551176 -0300
@@ -14,6 +14,8 @@
     # to <VirtualHost *:443>
     # Server Name Indication for SSL named virtual hosts is currently not
     # supported by MSIE on Windows XP.
+    # PaTcHeD
+    NameVirtualHost *:443
     Listen 443
 </IfModule>

EOF
fi

sudo sed -i.original -e "s/_default_/*/" /etc/apache2/sites-available/default-ssl

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
        SSLProxyEngine on
        SSLCertificateFile ${CERT_FILE}
        SSLCertificateKeyFile ${CERT_KEY}
        SSLCertificateChainFile ${CERT_CHAIN_FILE}
        BrowserMatch ".*MSIE.*" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0

        RewriteEngine On
        RewriteRule ^/\$ /r [R,L]

        <Location /r>
            RewriteEngine On
            RewriteRule /(r.*) http://127.0.0.1:5000/\$1 [L,P]
            SetEnvIf X-Url-Scheme https HTTPS=1
        </Location>
    </VirtualHost>
</IfModule>
EOF
sudo cp $TMPDIR/git-ssl /etc/apache2/sites-available/

sudo a2ensite git git-ssl

# Setting up Whoosh full text search
(cd ~/rhodecode; paster make-index production.ini)
crontab -l >$TMPDIR/cron || true
if grep -q rhodecode $TMPDIR/cron; then
    : crontab already configured
else
    echo '@daily cd rhodecode; /home/git/venv/bin/paster make-index production.ini' >>$TMPDIR/cron
    crontab $TMPDIR/cron
fi

# Start up everything
sudo service rhodecode start
sudo service apache2 restart
