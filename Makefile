PG_CONFIG = pg_config
PKG_CONFIG = pkg-config

extension_version = 0.14

EXTENSION = datalink
DATA_built = datalink--$(extension_version).sql

REGRESS = init type sqlmed other link linker uri
REGRESS_OPTS = --inputdir=test

SCRIPTS = bin/pg_datalinker

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

installcheck: testfiles

testfiles:
	if [ ! -d /var/www/datalink ] ; then mkdir /var/www/datalink ; fi
	cp CHANGELOG.md /var/www/datalink/
	if [ ! -f /var/www/datalink/test1.txt ] ; then touch /var/www/datalink/test1.txt ; fi
	if [ ! -f /var/www/datalink/test2.txt ] ; then date >> /var/www/datalink/test2.txt ; fi
	date >> /var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced

datalink--$(extension_version).sql: datalink.sql
	cat $^ >$@
