Git Server
==========

A script to automatize the configuration of a
[Gitorious](gitorious.org) system on an Ubuntu server. The script is
heavilly inspired in [this blog
post](http://coding-journal.com/installing-gitorious-on-ubuntu-11-04/),
but it was developed on a Ubuntu Server 12.04.

It's still very crude. Follow this instructions:

* Install a Ubuntu Server 12.04 machine from scratch.
* Create a user called `git` and log in to it.
* Copy the files `gitorious-install.sh` and `gitorious-install.config.example` to git's `$HOME`.
* Edit `gitorious-install.config.example` according to your environment.
* Run `./gitorious-install.sh gitorious-install.config.example` as the git user.

The script uses `sudo` in order to invoke some commands as root. So,
you'll need to enable the git user to invoke sudo.

If all goes well you'll only have to enter the Gitorious administrator
login and password at the end of the installation.

At the end you should be able to point your browser to the
`SERVERNAME` as configured in `gitorious-install.config.example` and
log in as admin or as any user in your LDAP directory.
