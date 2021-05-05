CREATE OR REPLACE FUNCTION global.auto_update_date()
	RETURNS TRIGGER AS
$$
BEGIN

IF current_setting('dwh.auto_update_date', TRUE)::BOOLEAN THEN

	NEW.date_updated := now();
	-- important: this assumes the recipient table has a column named "date_updated"
END IF;

RETURN new;

END;
$$
LANGUAGE PLPGSQL
;

CREATE OR REPLACE PROCEDURE global.date_update_trigger_initializer(
	IN schema_list TEXT[] DEFAULT NULL
,	IN tables_included TEXT[] DEFAULT NULL
,	IN tables_excluded TEXT[] DEFAULT NULL
) AS
$$
DECLARE
	each_row RECORD;
	exec_sql TEXT;
BEGIN


/*

Usage:

CALL date_update_trigger_initializer(); -- this will apply to ALL tables in ALL schemas
CALL date_update_trigger_initializer('{<schema_list>}'); -- this will apply to ALL tables in the specified schema(s)
CALL date_update_trigger_initializer(NULL, '{<table_include_list>}'); -- this will apply to any table specified in the list - regardless of which schema
CALL date_update_trigger_initializer(NULL, NULL,'{table_exclude_list}'); -- this will apply to any table NOT specified in the list - regardless of which schema

To enable:

ALTER DATABASE dwh_v1 SET dwh.auto_update_date = 'TRUE';
SELECT set_config('dwh.auto_update_date') = 'TRUE';

*/

FOR each_row IN (
	select
		event_object_schema
	,	event_object_table
	from information_schema.triggers
	where
		trigger_name = 'auto_update_date'
)
LOOP

exec_sql := 'DROP TRIGGER IF EXISTS auto_update_date ON "%1$s"."%2$s";';

exec_sql := format(exec_sql
	,	each_row.event_object_schema
	,	each_row.event_object_table
	)
;

-- raise info '%', exec_sql;

EXECUTE exec_sql;

END LOOP;

FOR each_row IN (
	select
		table_name
	,	table_schema
	from information_schema.columns
	JOIN information_schema.tables USING (table_catalog, table_schema, table_name)
	WHERE
		table_type = 'BASE TABLE'
	AND column_name = 'date_updated'
	AND table_schema = ANY( COALESCE( schema_list, array[current_schema()] ) )
	AND COALESCE(table_name = ANY(tables_included), TRUE)
	AND NOT COALESCE(table_name = ANY(tables_excluded), FALSE)
)
LOOP

exec_sql := '

CREATE TRIGGER auto_update_date
	BEFORE UPDATE ON "%1$s"."%2$s"
	FOR EACH ROW
	EXECUTE FUNCTION auto_update_date()
;
'
;

exec_sql := format(exec_sql
	,	each_row.table_schema
	,	each_row.table_name
	)
;

-- raise info '%', exec_sql;

EXECUTE exec_sql;

END LOOP;


END;
$$
LANGUAGE PLPGSQL
;