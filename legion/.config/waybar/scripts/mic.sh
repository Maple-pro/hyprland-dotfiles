#!/usr/bin/env bash

state="$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}')"

if [ "$state" = "yes" ]; then
  printf '{"text":"","tooltip":"Microphone muted","class":"muted"}\n'
else
  printf '{"text":"","tooltip":"Microphone active","class":"active"}\n'
fi
