/*

The function returns a list of table names with the current size (in bytes and human-readable units) and rate of growth for both the table and all its associated indexes. It also includes Temporary file activity.

The results are not a formal view, but they are a good approximate. Depending on the query, the activity may not be immediately viewable in terms of writes to a table. However, in those times, there is often evidence in the "temp_files".

Usage:

select * from table_build_monitor(<table_or_schema_list>, <sample_period>);

table_or_schema_list: 
An array of schema-qualified table name(s) or schema name(s).
Example: '{public.*, your_schema.your_table}'

sample_period:
How long to sample activity over.
Optional - default 10s

*/



CREATE OR REPLACE FUNCTION table_build_monitor(
	IN table_or_schema_list TEXT[] DEFAULT NULL
,	IN sample_period INT DEFAULT 10
)
RETURNS TABLE (
	table_name TEXT
,	table_size TEXT
,	index_size TEXT
)
AS
$$
DECLARE
	table_list TEXT[];
	schema_list TEXT[];
BEGIN

DROP TABLE IF EXISTS table_sizes_loop;
CREATE TEMP TABLE table_sizes_loop (
	table_name_loop TEXT
,	table_size_bytes BIGINT
,	indexes_size_bytes BIGINT
)
;

select
	array_remove(array_agg(case when split_part(poo, '.',2) = '*' then split_part(poo, '.',1) else NULL end), NULL::TEXT)
,	array_remove(array_agg(case when split_part(poo, '.',2) = '*' then NULL else poo end), NULL::TEXT)
FROM unnest(array[table_or_schema_list]) poo
INTO schema_list, table_list
;

INSERT INTO table_sizes_loop

SELECT
	pg_tables.schemaname||'.'|| pg_tables.tablename as table_name
,	pg_relation_size(pg_tables.schemaname||'.'|| pg_tables.tablename) AS table_size_bytes
,	pg_indexes_size(pg_tables.schemaname||'.'|| pg_tables.tablename) AS indexes_size_bytes
FROM pg_tables
WHERE
	pg_tables.schemaname = ANY(schema_list)
OR	(pg_tables.schemaname||'.'|| pg_tables.tablename)::text = ANY(table_list)

UNION

SELECT
	'temp_files'
,	temp_bytes
,	NULL
FROM pg_stat_database
WHERE
	datname = current_database()
;

PERFORM pg_sleep(sample_period);

RETURN QUERY

with
	base AS
(
SELECT
	pg_tables.schemaname||'.'|| pg_tables.tablename as table_name_loop
,	pg_relation_size(pg_tables.schemaname||'.'|| pg_tables.tablename) AS table_size_bytes
,	pg_indexes_size(pg_tables.schemaname||'.'|| pg_tables.tablename) AS indexes_size_bytes

FROM pg_tables
WHERE
	pg_tables.schemaname::text = ANY(schema_list)
OR	(pg_tables.schemaname||'.'|| pg_tables.tablename)::text = ANY(table_list)

UNION

SELECT
	'temp_files'
,	temp_bytes
,	NULL
FROM pg_stat_database
WHERE
	datname = current_database()

)
SELECT
	table_name_loop
,	CASE WHEN table_name_loop = 'temp_files' THEN
		pg_size_pretty((base.table_size_bytes - tsl.table_size_bytes)/sample_period) || '/s'
	ELSE
			base.table_size_bytes
		|| ' (' || pg_size_pretty((base.table_size_bytes))
		|| ') - ' || pg_size_pretty((base.table_size_bytes - tsl.table_size_bytes)/sample_period) || '/s'
	END	as table_size
,		base.table_size_bytes
	|| ' (' || pg_size_pretty((base.indexes_size_bytes))
	|| ') - ' || pg_size_pretty((base.indexes_size_bytes - tsl.indexes_size_bytes)/sample_period) || '/s'
	as table_size
FROM table_sizes_loop tsl
JOIN base USING (table_name_loop)
ORDER BY base.table_size_bytes DESC
;

END
$$
LANGUAGE plpgsql
;