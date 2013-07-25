#!/bin/bash

DAT1=/tmp/zabbix-nginx-offset.dat
ACCESSLOG=/var/log/nginx/access.log

/usr/sbin/logtail2 -f$ACCESSLOG -o$DAT1 | perl /home/scripts/zabbix-nginx-stats.pl

