CREATE OR REPLACE PROCEDURE drop_all_triggers(
	IN schema_in TEXT
) AS
$$
DECLARE
	each_trigger RECORD;
	sql_exe TEXT;
BEGIN

sql_exe := 'DROP TRIGGER IF EXISTS %1$s ON %2$s.%3$s;'; -- not putting any cascade on here... because what depends on a trigger??

FOR each_trigger IN
	(
	SELECT
		tgrelid::regclass as table_name
	,	tgname as trigger_name
	FROM pg_trigger
	WHERE
		NOT tgisinternal
	AND tgrelid::regclass IN (SELECT tablename::regclass FROM pg_tables WHERE schemaname = schema_in)
	)
LOOP

	EXECUTE
-- 	RAISE INFO '%',
		format(sql_exe, each_trigger.trigger_name, schema_in, each_trigger.table_name);

END LOOP;


END
$$
LANGUAGE plpgsql
;