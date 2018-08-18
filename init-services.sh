#!/bin/sh

nohup /usr/bin/mysqld_safe --datadir="/var/lib/mysql" &
sleep 3

crond -L /var/log/cron

/usr/sbin/httpd -k start -f /etc/apache2/httpd.conf

tail -f /var/log/cacti/cacti.log