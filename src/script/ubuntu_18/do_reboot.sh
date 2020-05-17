#!/usr/bin/env bash

echo "do_reboot.sh is starting..."

nohup bash -c 'sleep 2; reboot' &
