PG_CONFIG = pg_config
PKG_CONFIG = pkg-config

extension_version = 0.2

EXTENSION = datalinker
DATA_built = datalinker--$(extension_version).sql

REGRESS = init basic other
REGRESS_OPTS = --inputdir=test

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

datalinker--$(extension_version).sql: datalinker.sql
	cat $^ >$@
