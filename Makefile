PG_CONFIG = pg_config
PKG_CONFIG = pkg-config

extension_version = 0.25

EXTENSION = datalink
DATA_built = datalink--$(extension_version).sql
PROGRAM = dlcat pg_dlfuse
INCLUDES = -I/usr/include/postgresql
PG_LIBS = -L$(shell $(PG_CONFIG) --pkglibdir)
BINDIR = $(shell $(PG_CONFIG) --bindir)

REGRESS = init type sqlmed selective link linker uri user bfile
REGRESS_OPTS = --inputdir=test

SCRIPTS = bin/pg_datalinker bin/dlfs

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

INSTALL_PROGRAM = $(INSTALL) -m 6755 -o www-data -g www-data

install: installextras

installcheck: testfiles

installextras:
	if [ ! -f /usr/sbin/pg_datalinker ] ; then ln -s /usr/share/postgresql-common/pg_wrapper /usr/sbin/pg_datalinker ; fi
	if [ ! -f /usr/sbin/dlfs ] ; then ln -s /usr/share/postgresql-common/pg_wrapper /usr/sbin/dlfs ; fi
	if [ ! -f /usr/bin/dlcat ] ; then ln -s /usr/share/postgresql-common/pg_wrapper /usr/bin/dlcat ; fi
	if [ ! -f /usr/sbin/pg_dlfuse ] ; then ln -s /usr/share/postgresql-common/pg_wrapper /usr/sbin/pg_dlfuse ; fi
	if [ ! -f /etc/postgresql-common/pg_datalinker.prefix ] ; then /usr/bin/install -m 644 pg_datalinker.prefix /etc/postgresql-common ; fi
	if [ ! -f /etc/apache2/sites-available/datalink.conf ] ; then /usr/bin/install -m 644 datalink.conf /etc/apache2/sites-available ; fi
	/usr/bin/install -m 644 pg_datalinker.service /etc/systemd/system
	systemctl daemon-reload

testfiles:
	if [ ! -d /var/www/datalink ] ; then mkdir /var/www/datalink ; fi
	chgrp postgres /var/www/datalink ; chmod g+w /var/www/datalink
#	cp CHANGELOG.md /var/www/datalink/CHANGELOG.md
	echo "Hello" > /var/www/datalink/test1.txt
	cp docs/utf8.txt /var/www/datalink/test2.txt
	cp -a LICENSE.md /var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced
	rm -f /var/www/datalink/test3.txt
	date +%F > /var/www/datalink/test4.txt
	rm -f /var/www/datalink/test5.txt /var/www/datalink/test6.txt
	mkdir -p /var/www/datalink/installcheck/
	rm -f /var/www/datalink/installcheck/*
	rm -f /var/www/datalink/installcheck_*

dump-test:
	pg_dump -Fc contrib_regression > db.pg_dump
	dropdb contrib_regression
	pg_restore -v -C -d postgres db.pg_dump

datalink--$(extension_version).sql: datalink.sql
	cat $^ >$@

dlcat: dlcat.c
	$(CC) -Wall -Wextra -I`$(PG_CONFIG) --includedir` dlcat.c -lpq -o dlcat
	chown www-data:www-data dlcat
	chmod 755 dlcat
	chmod g+s dlcat
	chmod u+s dlcat

pg_dlfuse: pg_dlfuse.c
	$(CC) -Wall -Wextra -I`$(PG_CONFIG) --includedir` -D_FILE_OFFSET_BITS=64 pg_dlfuse.c -lpq -lfuse -o pg_dlfuse

testall.sh:
	pg_lsclusters -h | perl -ne '@_=split("\\s+",$$_); print "make PGPORT=$$_[2] PG_CONFIG=/usr/lib/postgresql/$$_[0]/bin/pg_config clean install installcheck\n";' > testall.sh
