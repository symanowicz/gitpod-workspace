#!/bin/bash
: "${DISPLAY:=":0"}"
export DISPLAY
exec xterm &
exec cwm