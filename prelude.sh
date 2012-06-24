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

USAGE="usage: `basename $0` [-s] CONFIGFILE"
SKIP_INSTALL=0
CONFIG=server.conf
while getopts :sq OPT; do
    case $OPT in
	s) SKIP_INSTALL=1 ;;
	*)
	    echo >&2 $USAGE 
	    exit 2
    esac
done
shift `expr $OPTIND - 1`

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
fi

TMPDIR=`mktemp -d /tmp/tmp.XXXXXXXXXX` || exit 1
trap "rm -rf $TMPDIR" EXIT

set -x

# Grok configuration
source "$CONFIG"

# Check if all config variables are set
cat >/dev/null <<EOF
${GITURL}
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

# Bootstrap local Git installation
source ./git-bootstrap.sh

# Find out the name of the most recent Git release tag
GITTAG=`(cd ~/git; git tag -l) | grep '^v[0-9.]*$' | sort --version-sort | tail -1`

# Add ~/bin to the front of PATH and link scripts there
PATH=~/bin:$PATH
ln -s $PWD/git-install.sh ~/bin

# Install last Git release
~/bin/git-install.sh -v $GITTAG

# Stow it
(cd ~/stow; stow git-$GITTAG)

# Set up git
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
git config --global color.ui true

# Install RhodeCode
source ./rhodecode-install.sh
