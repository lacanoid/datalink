PG_CONFIG = pg_config
PKG_CONFIG = pkg-config

extension_version = 0.4

EXTENSION = datalink
DATA_built = datalink--$(extension_version).sql

REGRESS = init type basic other link
REGRESS_OPTS = --inputdir=test

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

datalink--$(extension_version).sql: datalink.sql
	cat $^ >$@
