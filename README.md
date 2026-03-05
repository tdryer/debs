# debs

`debs` is a personal Debian package build system. New packages versions are
built nightly using a systemd timer and made available to `apt` using
[`local-apt-repository`][0].

[0]: https://salsa.debian.org/debian/local-apt-repository

## Setup

Set up the systemd timer using the included Ansible playbook:

    just playbook

Or, trigger a build manually:

    just build
