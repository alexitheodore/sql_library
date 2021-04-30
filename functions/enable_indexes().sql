CREATE OR REPLACE PROCEDURE global.enable_indexes(
	IN schema_name TEXT
,	IN table_name TEXT
,	IN index_name TEXT
,	IN enable_use BOOLEAN
,	IN enable_updates BOOLEAN
,	IN skip_essentials BOOLEAN DEFAULT TRUE
) AS
$$
DECLARE
	each_record RECORD;
BEGIN

/*
USAGE:

schema_name:
- filters down by schema name
- if NULL then does not filter
table_name:
- filters down by table name (careful - not schema qualified)
- if NULL then does not filter
index_name:
- filters down by index name (careful - not schema qualified)
- if NULL then does not filter
enable_use:
- This SETs the index as being available for use.
- If enable_updates is FALSE, then automatically FALSE
enable_updates:
- This SETs the index to be updated (which doesn't imply that it is enabled for use)
- When this was previously FALSE for the given index, then when setting to true will also trigger a rebuild of the index
skip_essentials:
- When this is true, PRIMARY and UNIQUE indexes will not be included in the scope (no changes).
- Optional
*/


IF array_replace(ARRAY[schema_name, table_name, index_name], NULL, '') <@ ARRAY[''] THEN
	RAISE EXCEPTION 'Error: Must specify at least one of schema_name | table_name | index_name';
END IF;

IF enable_updates IS FALSE THEN
	enable_use := FALSE;
	RAISE INFO 'FYI: Because enable_updates is FALSE, then likewise enable_use must be as well';
END IF;

FOR each_record IN
	select
		indexrelid
	,	(schemaname||'.'||indexname) as index_name
	,	indisvalid
	,	indisready
	,	(schemaname||'.'||tablename) as table_name
	,	(CASE WHEN indisready IS FALSE and enable_use IS TRUE AND enable_updates IS TRUE THEN TRUE ELSE FALSE END) as needs_rebuilding
	FROM pg_indexes, pg_index
	WHERE
		indexrelid = (schemaname||'.'||indexname)::regclass
	AND	case when schema_name <> '' THEN schemaname = schema_name ELSE TRUE END
	AND case when table_name <> '' THEN tablename = table_name ELSE TRUE END
	AND case when index_name <> '' THEN indexname = index_name ELSE TRUE END
	AND case when true THEN least(indisprimary, indisunique) = FALSE ELSE TRUE END
	AND case when skip_essentials THEN least(indisprimary, indisunique) = FALSE ELSE TRUE END
LOOP
	BEGIN

	RAISE INFO 'Set index % to have use % and updates %.'
		,	each_record.index_name
		,	(case when each_record.indisvalid AND enable_use THEN 'enabled (not changed)' WHEN NOT each_record.indisvalid AND enable_use THEN 'enabled (changed)' else 'disabled' END)
		,	(case when each_record.indisready AND enable_updates THEN 'enabled (not changed)' WHEN NOT each_record.indisready AND enable_updates THEN 'enabled (changed)' else 'disabled' END)
	;

	UPDATE pg_index
	SET
		indisvalid = enable_use
	,	indisready = enable_updates
	WHERE
		indexrelid = each_record.indexrelid
	;

	IF each_record.needs_rebuilding THEN
		RAISE INFO '... Reindexing and Analyzing %', each_record.index_name;
		EXECUTE format('REINDEX INDEX %1$s; ANALYZE %2$s;', each_record.index_name, each_record.table_name);
	END IF;

	COMMIT;

	END;

END LOOP;

END
$$
LANGUAGE plpgsql
;


-- CALL enable_indexes('your_schema', '', '', TRUE, TRUE);