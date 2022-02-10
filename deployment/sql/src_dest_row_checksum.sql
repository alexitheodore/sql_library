DO
$$
DECLARE
	each_table RECORD;
BEGIN


DROP TABLE IF EXISTS table_counts;
CREATE TEMP TABLE table_counts
(
	schema_name TEXT
,	table_name TEXT
,	count_src BIGINT
,	count_dest BIGINT
)
;

FOR each_table IN (
	SELECT
		schemaname
	,	tablename
	,	0::BIGINT as row_count_src
	,	0::BIGINT as row_count_dest
	FROM pg_tables
	WHERE
		schemaname IN ('application', 'reporting', 'global')
)
LOOP

	EXECUTE format('SELECT count(*) FROM %1$s.%2$s;', each_table.schemaname, each_table.tablename) INTO each_table.row_count_dest;
	EXECUTE format('SELECT count(*) FROM source_%1$s.%2$s;', each_table.schemaname, each_table.tablename) INTO each_table.row_count_src;

	INSERT INTO table_counts
	VALUES
		(each_table.schemaname, each_table.tablename, each_table.row_count_src, each_table.row_count_dest)
	;

END LOOP
;

END
$$
LANGUAGE plpgsql
;

\echo '	Source->Dest Row count differences (if any)'
SELECT * FROM table_counts where count_src <> count_dest
;