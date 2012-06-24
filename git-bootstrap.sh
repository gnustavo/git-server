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

# Install Ubuntu packages needed to build git.
sudo apt-get install libcurl4-gnutls-dev libexpat1-dev gettext \
    libz-dev libssl-dev make stow tk

# Install git package to bootstrap things.
sudo apt-get install git

# Create the git users SSH directory if it doesn't already exist
mkdir -p ~/.ssh && chmod 700 ~/.ssh

# Create build and deployment directories
mkdir -p ~/{bin,src,stow}

# Clone git into git directory
(cd ~; git clone ${GITURL} git)

# Setup Git origin URL
(cd ~/git; git remote set-url origin git://git.kernel.org/pub/scm/git/git.git)
