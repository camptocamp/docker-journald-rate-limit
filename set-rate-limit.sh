#!/bin/sh -e

JOURNALD_CONF="/etc/systemd/journald.conf"
JOURNALD_PROCNAME="/lib/systemd/systemd-journald"

test -n "$BURST" || \
  (echo "empty \$BURST value"; exit 1)
test -n "$INTERVAL" || \
  (echo "empty \$INTERVAL value"; exit 1)
test "$BURST" -ge 0 || \
  (echo "non-postitive integer \$BURST value: '$BURST'"; exit 1)
echo "$INTERVAL" | grep -Eq '^[0-9]+(s|min|h|ms|us)?$' || \
  (echo "invalid \$INTERVAL value: '$INTERVAL'"; exit 1)
test -w "$JOURNALD_CONF" || \
  (echo "$JOURNALD_CONF not writeable"; exit 1)
test "$(pgrep -f $JOURNALD_PROCNAME | wc -l)" -eq 1 || \
  (echo "not exactly 1 process name matching '$JOURNALD_PROCNAME'"; exit 1)

sed -r -i \
    -e "s/.*#?(RateLimitIntervalSec=).*/\1$INTERVAL/i" \
    -e "s/.*#?(RateLimitBurst=).*/\1$BURST/i" \
    "$JOURNALD_CONF"

if ! grep -qE '^RateLimitIntervalSec=' "$JOURNALD_CONF"; then
  echo "RateLimitIntervalSec=$INTERVAL" >> "$JOURNALD_CONF"
fi

if ! grep -qE '^RateLimitBurst=' "$JOURNALD_CONF"; then
  echo "RateLimitBurst=$BURST" >> "$JOURNALD_CONF"
fi

pkill -f "$JOURNALD_PROCNAME" || (echo "Failed to reload journald process"; exit 1)

sleep 5

if ! [ "$(pgrep -f $JOURNALD_PROCNAME | wc -l)" -gt 0 ]; then
  echo "no journald process found, rolling back to built-in defaults"
  sed -r -i \
      -e "/^RateLimitIntervalSec=.*/Id" \
      -e "/^RateLimitBurst=.*/Id" \
      "$JOURNALD_CONF"
  exit 1
fi

echo "journald settings are set as follows:"
egrep 'RateLimitIntervalSec|RateLimitBurst' "$JOURNALD_CONF"
