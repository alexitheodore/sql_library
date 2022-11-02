

/*
This script logs tuple changes on a table and saves them to a `table_changes`. It can be used for any/multiple tables.

To use, execute this file and then run:

`CALL setup_table_change_logging('<schema_name>', '<table_name>', '{[column_name, ... ]}');`

On every table you want logged.

*/

CREATE OR REPLACE FUNCTION log_table_changes() RETURNS TRIGGER AS
$$
DECLARE
	table_changes JSONB;
	tbl_pk TEXT;
BEGIN

-- if logging is disabled (only effective for the current session) then skip
IF upper(current_setting('flywheel.status.log_table_changes', TRUE)) = 'DISABLED' THEN RETURN NULL; END IF;

-- get the table changes in JSON format
table_changes :=
CASE TG_OP
	WHEN 'INSERT' THEN row_to_json(NEW)::JSONB
	WHEN 'DELETE' THEN row_to_json(OLD)::JSONB
	ELSE jsonb_delta(row_to_json(OLD)::JSONB, row_to_json(NEW)::JSONB)
END
;

-- grab the primary key(s)
tbl_pk := array_to_string(
		jsonb_path_query_array(
			((CASE TG_OP WHEN 'UPDATE' THEN row_to_json(OLD)::JSONB ELSE table_changes END) #& ((TG_ARGV[0])::TEXT[]))
		,	('$.*')::JSONPATH
		)::TEXT[]
	,	':'
	)
	;


IF	TG_ARGV[1] = '{}' -- if no columns have been selected, then always log everything
OR	(table_changes ?| ((TG_ARGV[1])::TEXT[])) -- otherwise, only if the changes are in the list of selected columns
THEN
	INSERT INTO table_changes_staging
		(schema_name, table_name, event, changes, primary_key)
	VALUES
		(TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, table_changes, tbl_pk)
	;
END IF
;

RETURN NULL;

END
$$
LANGUAGE plpgsql
;



CREATE OR REPLACE PROCEDURE setup_table_change_logging(
	IN schema_name TEXT
,	IN table_name TEXT
,	IN columns TEXT[]
)
AS
$$
DECLARE
	sql_exe TEXT;
	tbl_pks TEXT;
BEGIN

CREATE TABLE IF NOT EXISTS table_changes
(
	schema_name TEXT
,	table_name TEXT
,	primary_key TEXT
,	event TEXT
,	changes JSONB
,	date_logged TIMESTAMPTZ DEFAULT now()
,	txid BIGINT DEFAULT txid_current()
)
;
CREATE INDEX IF NOT EXISTS table_changes_table_name ON table_changes (table_name, primary_key);


/*
In order to reduce the burden of auditing to a minimum, the immediate record of an audit is saved to an UNLOGGED table.
Later on, those records are flushed to the main LOGGED table via the `archive_table_changes` procedure.

Note: in the event of a crash or system shutdown, this means that any un-archived data will be lost.

*/
CREATE UNLOGGED TABLE table_changes_staging () INHERITS (table_changes)
;




-- find the primary key for the table
SELECT
	array_agg(a.attname::TEXT)::TEXT
INTO tbl_pks
FROM   pg_index i
JOIN   pg_attribute a ON a.attrelid = i.indrelid
                     AND a.attnum = ANY(i.indkey)
WHERE  i.indrelid = (schema_name||'.'||table_name)::regclass
AND    i.indisprimary
;


sql_exe :=
$sql$

DROP TRIGGER IF EXISTS %2$s_log_changes
	ON %1$s.%2$s
;
CREATE TRIGGER %2$s_log_changes
	AFTER INSERT OR UPDATE OR DELETE
	ON %1$s.%2$s
	FOR EACH ROW
	EXECUTE FUNCTION log_table_changes('%3$s', '%4$s')
;

$sql$
;

sql_exe :=
	format(sql_exe
	,	schema_name
	,	table_name
	,	coalesce(tbl_pks, '{}')
	,	coalesce(columns, '{}')
	);

-- RAISE INFO '%', sql_exe; --< uncomment to diagnose

EXECUTE sql_exe;

END
$$
LANGUAGE plpgsql
;


CREATE OR REPLACE PROCEDURE archive_table_changes() AS
$$
BEGIN
/*
This procedure moves data from the unlogged staging table to the logged (main) one. It should be run as routinely as
possible to maintain data integrity.

*/

WITH
	dels as
(
DELETE FROM table_changes_staging
RETURNING *
)
INSERT INTO table_changes SELECT * FROM dels
;

END
$$
LANGUAGE plpgsql
SECURITY DEFINER
;