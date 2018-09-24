FROM alpine:latest

ENV CACTI_VERSION latest

# Install all the things we need to do everything.
RUN /sbin/apk --no-cache upgrade && \
	/sbin/apk --no-cache add openrc apache2 mariadb mariadb-client php7 cacti cacti-php7 vim php7-apache2 net-snmp curl tzdata cacti-setup wget patch gd php7-dom automake libtool autoconf make gawk gcc g++ distcc binutils libressl-dev mysql-dev net-snmp-dev help2man linux-headers iputils php7-ctype

# Move all the default configs into a backup location,
# from where they _might_ be restored later in the container startup process
# Startup scripts check for existing resources and copy in defauts if none are found or recognized
RUN BACKUPDIR="/root/default-configs" && \
	mkdir -p ${BACKUPDIR}/mysql && \
	mv /etc/mysql/my.cnf ${BACKUPDIR}/mysql/ && \
	mkdir -p ${BACKUPDIR}/apache && \
	mv /etc/apache2/* ${BACKUPDIR}/apache/ && \
	mkdir ${BACKUPDIR}/php7 && \
	mv /etc/php7/* ${BACKUPDIR}/php7/

# Misc locations and things
RUN	mkdir -p /run/apache2 && \
	mkdir -p /run/openrc && \
	touch /run/openrc/softlevel && \
	mkdir -p /var/backups

# Update Cacti
# Start off with the in-distro version (installed by apk above), in order to set up dependencies and stuff.
# Then download and install the ${CACTI_VERSION} version of cacti on top of that.
RUN cd /tmp && \
	wget https://www.cacti.net/downloads/cacti-${CACTI_VERSION}.tar.gz && \
    PACKAGE_VERSION=$(tar -tf cacti-${CACTI_VERSION}.tar.gz | head -n1 | tr -d /) && \
	ln -s /usr/share/webapps/cacti /usr/share/webapps/${PACKAGE_VERSION} && \
	tar -xvf cacti-${CACTI_VERSION}.tar.gz -C /usr/share/webapps && \
	mkdir -p /usr/share/webapps/cacti/log && \
	touch /usr/share/webapps/cacti/log/cacti.log && \
	ln -s /usr/share/webapps/cacti /var/www/localhost/htdocs/cacti && \
	chown -R cacti:cacti /usr/share/webapps/cacti/ && \
	chown -R cacti:cacti /var/lib/cacti/ && \
	chown -R apache:apache /usr/share/webapps/cacti/cache/ && \
	chown -R apache:apache /usr/share/webapps/cacti/resource/ && \
	chown -R apache:apache /usr/share/webapps/cacti/scripts/ && \
	chown -R apache:apache /var/log/cacti/ && \
	rm -f /tmp/cacti-${CACTI_VERSION}.tar.gz

# Download and install spine.
# Naturally, spine's version is locked to cacti's version, because versioning.
# https://www.cacti.net/downloads/docs/html/unix_configure_spine.html
RUN cd /tmp && \
	wget http://www.cacti.net/downloads/spine/cacti-spine-${CACTI_VERSION}.tar.gz && \
	PACKAGE_VERSION=$(tar -tf cacti-spine-${CACTI_VERSION}.tar.gz | head -n1 | tr -d /) && \
	tar -zxvf cacti-spine-${CACTI_VERSION}.tar.gz && \
	cd ${PACKAGE_VERSION}/ && \
	/usr/bin/aclocal && \
	/usr/bin/libtoolize --force && \
	/usr/bin/autoheader && \
	/usr/bin/autoconf && \
	/usr/bin/automake --add-missing && \
	/usr/bin/aclocal && \
	/usr/bin/automake && \
	./configure && \
	/usr/bin/make && \
	/usr/bin/make install && \
	/bin/chown root:root /usr/local/spine/bin/spine && \
	/bin/chmod +s /usr/local/spine/bin/spine && \
	rm -rf /tmp/cacti-spine-${CACTI_VERSION}.tar.gz /tmp/cacti-spine-${CACTI_VERSION}

# Download and install hddtemp
# https://wiki.archlinux.org/index.php/Hddtemp
# https://www.cyberciti.biz/tips/howto-monitor-hard-drive-temperature.html
RUN cd /tmp && \
	wget http://download-mirror.savannah.gnu.org/releases/hddtemp/hddtemp-0.3-beta15.tar.bz2 && \
	tar -jxvf hddtemp-0.3-beta15.tar.bz2 && \
	cd hddtemp-0.3-beta15 && \
	./configure && \
	make && \
	make install && \
	rm -rf /tmp/hddtemp-0.3-beta15 /tmp/hddtemp-0.3-beta15.tar.bz2 && \
	mkdir -p /usr/share/misc && \
	wget -O /usr/share/misc/hddtemp.db http://download.savannah.nongnu.org/releases/hddtemp/hddtemp.db

# Bugs and other anomolies
# First and second lines: Apply a bug fix caused by PHP 7.2
RUN sed -i "s|\$ids = array()\;|\$ids = \'\'\;|" /usr/share/webapps/cacti/lib/utility.php && \
	sed -i "s|if (sizeof(\$ids))|if (strlen(\$ids))|" /usr/share/webapps/cacti/lib/utility.php

# Make sure all MIBs are active
RUN echo "mibs +ALL" >> /etc/snmp/snmpd.conf && \
    echo "mibs +ALL" >> /etc/snmp/snmp.conf

# Add our stuff
ADD container-prep /
ADD init-services /
ADD backup /
ADD restore /
ADD hddtemp.sh /
ADD hddtemp-cacti.sh /
ADD unRAID-Server.xml /
ADD Net-SNMP-Memory-Usage.xml /
ADD Net-SNMP-Load-Average.xml /
ADD Net-SNMP-CPU-Utilization.xml /

ENTRYPOINT ["/container-prep"]
