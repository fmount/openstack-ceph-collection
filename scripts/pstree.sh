#!/bin/env bash

declare -A children
for p in /proc/[0-9]*; do
  pid=${p##*/}
  ppid=$(awk '/^PPid:/{print $2}' "$p/status" 2>/dev/null)
  [ -n "$ppid" ] && children[$ppid]+="$pid "
done

print_tree() {
  local pid=$1 depth=$2
  local cmd
  cmd=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
  [ -z "$cmd" ] && cmd="[$(awk '/^Name:/{print $2}' /proc/$pid/status)]"
  printf "%*s%s (%s)\n" $((depth*2)) "" "$pid" "$cmd"
  for c in ${children[$pid]}; do
    print_tree "$c" $((depth+1))
  done
}

print_tree "${1:-1}" 0
