/*
This is a very simple and robust system for making certain columns automatically take on the current timestamp whenever their respective row is updated. With the universal infrastructure (trigger and respective function) in place, a quick procedure call will automatically apply the method to all columns with the name "date_updated".



*/


DROP SCHEMA IF EXISTS demo1 CASCADE;
CREATE SCHEMA demo1;
SET search_path TO demo1;


-- > auto-update-date-system

CREATE OR REPLACE FUNCTION auto_update_date()
	RETURNS TRIGGER AS
$$
BEGIN

NEW.date_updated := now();
NEW.date_created := OLD.date_created;

-- important: this assumes the recipient table has a column named "date_updated"

RETURN new;

END;
$$
LANGUAGE PLPGSQL
;

CREATE OR REPLACE PROCEDURE date_update_trigger_initializer(
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

raise info '%', exec_sql;

EXECUTE exec_sql;

END LOOP;

FOR each_row IN (
	select
		table_name
	,	table_schema
	from information_schema.columns
	WHERE
		column_name = 'date_updated'
	AND table_schema = ANY( COALESCE( schema_list, array[current_schema()] ) )
	AND COALESCE(table_name = ANY(tables_included), TRUE)
	AND NOT COALESCE(table_name = ANY(tables_excluded), FALSE)
)
LOOP

exec_sql := '

CREATE TRIGGER auto_update_date
    BEFORE UPDATE ON "%1$s"."%2$s"
    FOR EACH ROW
    WHEN (OLD.* IS DISTINCT FROM NEW.*)
    EXECUTE FUNCTION auto_update_date()
;
'
;

exec_sql := format(exec_sql
	,	each_row.table_schema
	,	each_row.table_name
	)
;

raise info '%', exec_sql;

EXECUTE exec_sql;

END LOOP;

END;
$$
LANGUAGE PLPGSQL
;

-- < auto-update-date-system

-- > CREATE all your tables

CREATE TABLE example_table (
	id serial
,	date_created TIMESTAMP
		NOT NULL
		DEFAULT now()
,	date_updated TIMESTAMP
		NOT NULL
		DEFAULT now()
,	other_columns TEXT
)
;

CREATE TABLE example_table2 (
	id serial
,	date_created TIMESTAMP
		NOT NULL
		DEFAULT now()
,	date_updated TIMESTAMP
		-- triggered to update every time /something/ changes
,	other_columns TEXT
)
;

-- > After having CREATEd all your tables, run the date_update_trigger_initializer() procedure (can be (re)run any time, safely)

CALL date_update_trigger_initializer();
-- CALL date_update_trigger_initializer('{demo1}');
-- CALL date_update_trigger_initializer(NULL, '{example_table2}');
-- CALL date_update_trigger_initializer(NULL, NULL,'{example_table2}');

-- > Some examples / proofs:

INSERT INTO example_table (other_columns) VALUES
('abc123')
;

SELECT * FROM example_table;

UPDATE example_table SET other_columns = 'xyz' RETURNING *;

UPDATE example_table SET date_created = NULL, date_updated = NULL RETURNING *;
