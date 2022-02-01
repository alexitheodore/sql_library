-- This script will truncate ALL tables in the specified schemas
CREATE OR REPLACE PROCEDURE truncate_all_tables(
	IN schema_in TEXT
) AS
$$
DECLARE
	each_table RECORD;
	sql_truncate TEXT;
BEGIN

sql_truncate :=
$sql$
	TRUNCATE TABLE %1$s.%2$s CASCADE;
$sql$
;

FOR each_table IN (
	SELECT
		*
	FROM information_schema.TABLES
	WHERE
		table_schema = schema_in
	AND table_type = 'BASE TABLE'
)
LOOP

EXECUTE format(sql_truncate
	,	each_table.table_schema
	,	each_table.table_name
	)
;

END LOOP;

END;
$$
LANGUAGE plpgsql
;