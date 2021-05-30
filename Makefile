PG_CONFIG = pg_config
PKG_CONFIG = pkg-config

extension_version = 0.13

EXTENSION = datalink
DATA_built = datalink--$(extension_version).sql

REGRESS = init type basic other link linker uri
REGRESS_OPTS = --inputdir=test

SCRIPTS = bin/pg_datalinker

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

installcheck: testfiles

testfiles:
	cp CHANGELOG.md /tmp
	touch /tmp/issue /tmp/hosts
	bin/pg_datalinker add /tmp/

datalink--$(extension_version).sql: datalink.sql
	cat $^ >$@
