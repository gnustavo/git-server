Git Server
==========

Scripts to automatize the configuration of a Git system on a Ubuntu
server.

Currently we install a [RhodeCode](http://rhodecode.org/) based
server.

The scripts are still very crude. Follow this instructions:

* Install a Ubuntu Server 12.04 machine from scratch.
* Create a user called `git` and make it be able to sudo root.
* Install the `git` package.
* Log in as `git` and do as follows:

	$ git clone git://github.com/gnustavo/git-server.git
	$ cd git-server
	$ cp server.conf.template server.conf
	$ edit server.conf
	$ ./install.sh

You must edit the file `server.conf` according with your environment,
following the comments in it.

The `install.sh` script simply runs the other scripts in this repo to
install RhodeCode, and then to build a local git binary.

The scripts use `sudo` in order to invoke some commands as root. So,
you'll need to enable the git user to invoke sudo.

At the end you should be able to point your browser to the
`SERVERNAME` as configured in `SYSTEM-install.config`.
