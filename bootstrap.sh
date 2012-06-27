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
${GITURL}
${GIT_USER_NAME}
${GIT_USER_EMAIL}
${SERVERNAME}
${CERT_FILE}
${CERT_KEY}
${CERT_CHAIN_FILE}
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

# Install packages needed to build Git.
sudo apt-get install gettext git libcurl4-gnutls-dev libexpat1-dev \
    libssl-dev libz-dev make stow tk

# Install packages needed to build RhodeCode.
sudo apt-get -y install apache2 libsasl2-dev python-dev \
    python-virtualenv rabbitmq-server

# Create the git users SSH directory if it doesn't already exist
mkdir -p ~/.ssh && chmod 700 ~/.ssh

# Clone git into git directory
(cd ~; git clone ${GITURL} git)

# Setup Git origin URL
(cd ~/git; git remote set-url origin git://git.kernel.org/pub/scm/git/git.git)

# Add ~/bin to the front of PATH and link some scripts there
mkdir -p ~/bin
for i in install-git.sh prelude.sh; do
    ln -s "$IDIR"/$i ~/bin
done

# Set up git
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
git config --global color.ui true
