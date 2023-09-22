PG_CONFIG = pg_config
PKG_CONFIG = pkg-config

extension_version = 0.21

EXTENSION = datalink
DATA_built = datalink--$(extension_version).sql

REGRESS = init type sqlmed selective link linker uri user bfile
REGRESS_OPTS = --inputdir=test

SCRIPTS = bin/pg_datalinker

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

install: installextras

installcheck: testfiles

installextras:
	if [ ! -f /sbin/pg_datalinker ] ; then ln -s /usr/share/postgresql-common/pg_wrapper /sbin/pg_datalinker ; fi
	if [ ! -f /etc/postgresql-common/pg_datalinker.prefix ] ; then /usr/bin/install -m 644 pg_datalinker.prefix /etc/postgresql-common ; fi
	/usr/bin/install -m 644 pg_datalinker.service /etc/systemd/system

testfiles:
	if [ ! -d /var/www/datalink ] ; then mkdir /var/www/datalink ; fi
	cp CHANGELOG.md /var/www/datalink/
	if [ ! -f /var/www/datalink/test1.txt ] ; then echo "Hello" > /var/www/datalink/test1.txt ; fi
	if [ ! -f /var/www/datalink/test2.txt ] ; then echo "This is for Friday, yeah." >> /var/www/datalink/test2.txt ; fi	
	cp README.md /var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced
	rm -f /var/www/datalink/test3.txt
	date > /var/www/datalink/test4.txt

dump:
	pg_dump -Fc contrib_regression > db.pg_dump
	dropdb contrib_regression
	pg_restore -v -C -d postgres db.pg_dump

datalink--$(extension_version).sql: datalink.sql
	cat $^ >$@
