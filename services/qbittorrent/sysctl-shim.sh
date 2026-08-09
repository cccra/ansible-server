#!/bin/bash
# /proc/sys is read-only in an unprivileged container, so wg-quick's
# `sysctl -q net.ipv4.conf.all.src_valid_mark=1` fails and its `set -e` tears the
# tunnel back down. Docker's --sysctl has already applied that value, so treat a
# write that requests the value already in place as success. A write that would
# actually change something still fails, loudly.
quiet=0
keys=()
for a in "$@"; do
  case "$a" in
    -q|--quiet) quiet=1 ;;
    -*) ;;
    *) keys+=("$a") ;;
  esac
done

for a in "${keys[@]}"; do
  key=${a%%=*}; key=${key// /}
  path=/proc/sys/${key//.//}
  if [[ ! -e $path ]]; then
    echo "sysctl: cannot stat $path: No such file or directory" >&2
    exit 1
  fi
  cur=$(< "$path")
  if [[ $a == *=* ]]; then
    val=${a#*=}; val=${val// /}
    if [[ $cur != "$val" ]]; then
      if ! echo "$val" > "$path" 2>/dev/null; then
        echo "sysctl: setting key \"$key\": Read-only file system" >&2
        exit 1
      fi
    fi
    (( quiet )) || echo "$key = $val"
  else
    echo "$key = $cur"
  fi
done
