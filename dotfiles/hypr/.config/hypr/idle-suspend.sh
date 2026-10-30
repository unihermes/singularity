#!/usr/bin/env bash
# The idle ladder's suspend (hypridle.conf's suspend steps). While the
# Hibernate step is on and logind can, it's suspend-then-hibernate, so a
# machine asleep before the step's time still hibernates, after
# HibernateDelaySec (sleep.conf.d, install.sh); otherwise a plain suspend.
conf=~/.config/hypr/hypridle.conf

if grep -Eq '^[[:space:]]*on-timeout[[:space:]]*=[[:space:]]*systemctl hibernate' "$conf" \
    && [[ $(busctl call org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager CanSuspendThenHibernate 2>/dev/null) == 's "yes"' ]]; then
  exec systemctl suspend-then-hibernate
fi
exec systemctl suspend
