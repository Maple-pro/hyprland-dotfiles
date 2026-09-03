#!/usr/bin/env bash

if pgrep -x mihomo-party >/dev/null 2>&1 || pgrep -f '^/opt/clash-party/mihomo-party([[:space:]]|$)' >/dev/null 2>&1; then
  printf '{"text":"󰛳","tooltip":"Clash Party running","class":"running"}\n'
else
  printf '{"text":"󰛳","tooltip":"Clash Party stopped","class":"stopped"}\n'
fi
