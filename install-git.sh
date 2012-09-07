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
source "$IDIR"/prelude.sh

USAGE="usage: `basename $0` [TAG]"

if [ $# -eq 1 ]; then
    TAG="$1"
else
    TAG=`(cd ~/git; git tag -l) | grep '^v[0-9.]*$' | grep -v -- -rc | sort --version-sort | tail -1`
    echo >&2 "# Building latest release TAG: $TAG."
fi

cd ~/git

git pull

GIT="git-$TAG"
DIR="$HOME/src/$GIT"

mkdir -p "$DIR"

git archive --format=tar "$TAG" | tar -C "$DIR" -x

cd "$DIR"

# Create build and deployment directories
mkdir -p ~/{bin,src}

# Create stow dir
if [ ! -d ~/stow ]; then
    mkdir ~/stow
    FIRSTTIME=yes
else
    FIRSTTIME=no
fi

make prefix="$HOME/stow/$GIT" install

if [ $FIRSTTIME = yes ]; then
    cd ~/stow
    stow $GIT
else
    cat <<EOF

Git $TAG installed in $HOME/stow/$GIT.
To enable it you must do this:

  cd ~/stow
  stow -D CURRENTLY_STOWED_GIT
  stow $GIT

EOF
fi
