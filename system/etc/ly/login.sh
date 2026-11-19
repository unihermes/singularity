#!/bin/sh
# Installed by singularity's install.sh. ly's login_cmd, run as the user: gives
# the session back the monitors outputs.sh held off for the greeter.
[ -s /run/singularity-ly-held ] && sudo -n /etc/ly/outputs.sh on
exec "$@"
