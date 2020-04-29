#!/usr/bin/env bash

echo "do_shutdown.sh is starting..."

nohup bash -c 'sleep 2; reboot' &
