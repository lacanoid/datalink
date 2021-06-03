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
	touch /var/www/datalink/test1.txt
	date >> /var/www/datalink/test2.txt

datalink--$(extension_version).sql: datalink.sql
	cat $^ >$@
