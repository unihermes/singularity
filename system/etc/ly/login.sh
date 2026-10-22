#!/bin/sh
# Installed by singularity's install.sh. ly's login_cmd, run as the user: gives
# the session back the monitors outputs.sh held off for the greeter.
grep -q 'video=[^ ]*:d\( \|$\)' /proc/cmdline && sudo -n /etc/ly/outputs.sh on
exec "$@"
