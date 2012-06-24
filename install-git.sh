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

USAGE="usage: `basename $0` [-v] [--] TAG"
while getopts :nv OPT; do
    case $OPT in
	v)
	    set -x
	    ;;
	*)
	    echo $USAGE
	    exit 2
    esac
done
shift `expr $OPTIND - 1`

TAG="$1"
if [ -z "$TAG" ]; then
    echo $USAGE
    echo "Missing TAG"
    exit 2
fi

cd ~/git

GIT="git-$TAG"
DIR="$HOME/src/$GIT"

mkdir -p "$DIR"

git archive --format=tar "$TAG" | tar -C "$DIR" -x

cd "$DIR"

make prefix="$HOME/stow/$GIT" install

cat <<EOF

Git $TAG installed in $HOME/stow/$GIT.
To enable it you must do this:

  cd ~/stow
  stow -D \$STOWED_GIT
  stow $GIT

EOF
