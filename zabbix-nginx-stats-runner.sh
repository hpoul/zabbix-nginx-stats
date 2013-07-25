#!/bin/bash

DAT1=/tmp/zabbix-nginx-offset.dat
ACCESSLOG=/var/log/nginx/access.log

dir=`dirname $0`

echo "=========" >> $dir/log.txt
date >> $dir/log.txt
/usr/sbin/logtail2 -f$ACCESSLOG -o$DAT1 | perl $dir/zabbix-nginx-stats.pl >> $dir/log.txt

