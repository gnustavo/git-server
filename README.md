Git Server
==========

Scripts to automatize the configuration of a Git system on a Ubuntu
server.

Currently we install a [RhodeCode](http://rhodecode.org/) based
server.

The scripts are still very crude. Follow this instructions:

* Install a Ubuntu Server 12.04 machine from scratch.
* Create a system user called `git` so that it's able to sudo root:

	# useradd -r -m git

* Install the `git` package:

	# apt-get install git

* Log in as `git` and clone this repo:

	# su - git
	$ git clone git://github.com/gnustavo/git-server.git
	$ cd git-server

* Copy the configuration template and edit it according to your
  environment following the instructions in its comments.

	$ cp server.conf.template server.conf
	$ edit server.conf

* Bootstrap the installation process, to check the configuration,
  install basic packages, clone the Git repository, and setup the
  environment.

	$ ./bootstrap.sh

* Build and install git. This is going to install the latest git in
  `/home/git/bin/git`. The script will be linked to
  `/home/git/bin/install-git.sh` so that it can be used later to
  install newer versions as they become available.

	$ ./install-git.sh

* Install RhodeCode.

	$ ./install-rhodecode.sh

At the end you should be able to point your browser to the
`SERVERNAME` as configured in `SYSTEM-install.config`.
