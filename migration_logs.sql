CREATE TABLE ldt_catalog.migration_logs
(
	dbv TEXT PRIMARY KEY
,	date_migrated TIMESTAMPTZ DEFAULT now()
)
;

