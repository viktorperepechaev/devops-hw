#!/usr/bin/env bash
set -u
export LC_ALL=C

fail() {
  echo "$1" >&2
  exit 2
}

[[ $# -eq 1 && -n "$1" ]] || fail "Usage: $0 SERVICE"
service_name="$1"

load_state=$(systemctl show --property=LoadState --value -- "$service_name") \
  || fail "Cannot inspect service: $service_name"

[[ -n "$load_state" && "$load_state" != "not-found" ]] \
  || fail "Service not found: $service_name"

service_state=$(systemctl is-active -- "$service_name")
printf 'Service: %s\nStatus: %s\n' "$service_name" "$service_state"

if [[ "$service_state" != "active" ]]; then
  journalctl -u "$service_name" -n 10 --no-pager \
    || fail "Cannot read service journal"
fi

log_file="/var/log/syslog"
[[ -r "$log_file" ]] || fail "Cannot read $log_file; run with sudo"

now=$(date -u '+%Y-%m-%dT%H:%M:%S')
since=$(date -u -d "$now UTC - 1 hour" '+%Y-%m-%dT%H:%M:%S') \
  || fail "Cannot calculate time range"

grep -Ei 'error|failed|failure|fatal' "$log_file" |
  awk -v since="$since" -v now="$now" '
    {
      timestamp = substr($1, 1, 19)
      if (timestamp >= since && timestamp <= now)
        count++
    }
    END {
      printf "Error log lines in last hour: %d\n", count + 0
    }
  '

statuses=("${PIPESTATUS[@]}")
((statuses[0] <= 1 && statuses[1] == 0)) || fail "Log processing failed"

[[ "$service_state" == "active" ]]
