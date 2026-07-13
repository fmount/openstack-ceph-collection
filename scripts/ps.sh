#!/bin/bash

printf "%-8s %-8s %-20s\n" "PID" "PPID" "CMD"
for p in /proc/[0-9]*; do
  pid=${p##*/}
  [ -r "$p/stat" ] || continue
  stat=$(cat "$p/stat")
  ppid=$(echo "$stat" | awk '{print $4}')
  cmd=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
  [ -z "$cmd" ] && cmd="[$(echo "$stat" | awk -F'[()]' '{print $2}')]"
  printf "%-8s %-8s %-20s\n" "$pid" "$ppid" "$cmd"
done
