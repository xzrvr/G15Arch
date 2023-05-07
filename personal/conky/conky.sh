#!/bin/bash
killall conky
sleep 20
conky -c ~/.conky/conky/conky.conf
