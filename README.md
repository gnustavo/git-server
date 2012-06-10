Git Server
==========

Scripts to automatize the configuration of a Git system on a Ubuntu
server.

Currently there are scripts to install a
[Gitorious](http://gitorious.org/) or a
[RhodeCode](http://rhodecode.org/) based server. You must choose one
of them, because they aren't meant to be independent.

The Gitorious script is heavilly inspired in [this blog
post](http://coding-journal.com/installing-gitorious-on-ubuntu-11-04/),
but it was developed on a Ubuntu Server 12.04.

They're still very crude. Follow this instructions:

* Install a Ubuntu Server 12.04 machine from scratch.
* Create a user called `git` and log in to it.
* Copy the files `SYSTEM-install.sh` and `SYSTEM-install.config`,
  corresponding to the system you want, to git's `$HOME`.
* Edit `SYSTEM-install.config` according to your environment.
* Run `./SYSTEM-install.sh SYSTEM-install.config` as the git user.
* Reboot.

The script uses `sudo` in order to invoke some commands as root. So,
you'll need to enable the git user to invoke sudo.

If all goes well you'll only have to enter the SYSTEM administrator
login and password after the end of the installation.

At the end you should be able to point your browser to the
`SERVERNAME` as configured in `SYSTEM-install.config` and log in as
admin or as any user in your LDAP directory.
