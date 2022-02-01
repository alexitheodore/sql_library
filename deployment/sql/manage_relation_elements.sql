\include_relative ../../functions/date_diff.sql

CREATE OR REPLACE PROCEDURE manage_relation_elements(
	IN mode TEXT
,	IN elements TEXT[]
,	IN schema_table_list TEXT[] DEFAULT NULL
,	IN element_names_in TEXT[] DEFAULT NULL
,	IN flags TEXT[] DEFAULT NULL
) AS
$$
DECLARE
	each_element RECORD;
	error_detail TEXT;
	tables_to_analyze TEXT[];
	exec_time TIMESTAMPTZ;
BEGIN

/*
USAGE:

For `schema_table_list`, each element must use the syntax "schema.table";
however, wildcards are allowed using the "%" character.
For example, "%.table_a" denotes table_a in any schema,
or "schema_b.%" denotes all tables in schema_b.

For `element_names_in`, simply supply the list of element_names (constraint name or index name as seen in `relation_element_logs` table).

*/

IF	coalesce(schema_table_list, element_names_in) IS NULL
	OR	(schema_table_list IS NOT NULL AND element_names_in IS NOT NULL)
	THEN
		RAISE EXCEPTION 'Must provide either `schema_table_list` or `schema_table_list` but not both.';
END IF;


/*
TODO:
[√] always retain element records, simply mark as enabled or disabled
[√] when an existing element exists in record, just update it, don't duplicate it
[√] whenever enabling an index, analyze each table



*/


CASE mode

WHEN 'disable' THEN

	-- the table may actually exist already and more stuff can be added to it.
	CREATE TABLE IF NOT EXISTS admin.relation_element_logs
	(
		id
			SERIAL
			PRIMARY KEY
	,	table_name
			TEXT
	,	element_type
			TEXT
	,	element_name
			TEXT
	,	create_def
			TEXT
	,	enabled_date
			TIMESTAMP
			DEFAULT NULL -- not stamped until enabled
	,	CONSTRAINT unique_element UNIQUE (table_name, create_def)
	)
	;

	IF 'constraints' = ANY(elements) THEN

	RAISE INFO 'Disabling Constraints...';

		FOR each_element IN
			select
				pg_get_constraintdef(cnt.oid) as con_def
			,	conname
			,	relname
			,	CASE contype
					WHEN 'p' then 0 -- primary keys should always go last so that all dependants can be done first
					WHEN 'f' then 1
					ELSE NULL
				END as drop_order
			,	cls.relnamespace::regnamespace::text as schema
			from pg_constraint cnt
			JOIN pg_class cls ON cls.oid = conrelid
			WHERE
				(
					(cls.relnamespace::regnamespace::text)||'.'||(relname) LIKE ANY(schema_table_list) -- schema.table
				AND relname NOT IN ('relation_element_logs') -- obviously need to skip this one...
				)
			OR conname = any(element_names_in)
			ORDER BY drop_order DESC NULLS LAST
		LOOP

			IF 'verbose' = any(flags) THEN
				RAISE INFO 'Disabling Constraint: %.%', each_element.relname, each_element.conname;
			END IF;

			EXECUTE format(
					'ALTER TABLE %1$s.%2$s DROP CONSTRAINT %3$s;'
				,	quote_ident(each_element.schema)
				,	quote_ident(each_element.relname)
				,	quote_ident(each_element.conname)
				)
			;

			INSERT INTO relation_element_logs
			(
				element_type
			,	table_name
			,	element_name
			,	create_def
			)
			VALUES
			(
				'constraint'
			,	(each_element.schema||'.'||each_element.relname)
			,	each_element.conname
			,	each_element.con_def
			)
-- 			ON CONFLICT ON CONSTRAINT unique_element -- if it already exists, set to disabled
-- 				DO UPDATE SET
-- 					enabled_date = NULL
			;

		END LOOP;
	END IF;

	IF 'indexes' = ANY(elements) THEN

	RAISE INFO 'Disabling Indexes...';

		FOR each_element IN
			SELECT
				pg_get_indexdef(indexrelid) as index_def
			,	pgc1.relname as table_name
			,	pgc2.relname as index_name
			,	indexrelid as index_id
			,	pgc2.relnamespace::regnamespace::text as schema
			FROM pg_index
			JOIN pg_class pgc1 ON indrelid = pgc1.oid
			JOIN pg_class pgc2 ON indexrelid = pgc2.oid
			WHERE
				TRUE
			AND	(
					NOT GREATEST(indisunique, indisprimary, indisexclusion) -- not linked to a constraint
				AND indislive
				AND (pgc2.relnamespace::regnamespace::text)||'.'||(pgc1.relname) LIKE ANY(schema_table_list) -- schema.table
				)
			OR pgc2.relname = any(element_names_in)
		LOOP
			IF 'verbose' = any(flags) THEN
				RAISE INFO 'Disabling Index: %.%', each_element.table_name, each_element.index_name;
			END IF;

			EXECUTE format(
					'DROP INDEX %1$s.%2$s;'
				,	quote_ident(each_element.schema)
				,	quote_ident(each_element.index_name)
				)
			;

			INSERT INTO relation_element_logs (
				element_type
			,	table_name
			,	element_name
			,	create_def
			)
			VALUES
			(	'index'
			,	(each_element.schema||'.'||each_element.table_name)
			,	each_element.index_name
			,	each_element.index_def
			)
			ON CONFLICT ON CONSTRAINT unique_element -- if it already exists, set to disabled
				DO UPDATE SET
					enabled_date = NULL
			;

		END LOOP;
	END IF;

/*
*/

WHEN 'enable' THEN

	IF 'constraints' = ANY(elements) THEN

	RAISE INFO 'Enabling Constraints...';

		FOR each_element IN
			select * from relation_element_logs
			WHERE
				element_type = 'constraint'
			AND CASE WHEN schema_table_list IS NULL THEN TRUE ELSE table_name LIKE ANY(schema_table_list) END -- schema.table
			AND coalesce(element_name = any(element_names_in), TRUE)
			AND enabled_date IS NULL
			ORDER BY id DESC
		LOOP
			IF 'verbose' = any(flags) THEN
				RAISE INFO 'Enabling Constraint: %.%', each_element.table_name, each_element.element_name;
			END IF;

			BEGIN
				exec_time := clock_timestamp();

				EXECUTE format('ALTER TABLE %1$s ADD %2$s;', each_element.table_name, each_element.create_def);

				IF 'verbose' = any(flags) THEN
					RAISE INFO 'Time: %s', date_diff(exec_time, clock_timestamp(), 'second');
				END IF;

				UPDATE relation_element_logs SET
					enabled_date = now()
				WHERE id = each_element.id
				;

				-- add to the list of tables that need to be analyzed at the end
				tables_to_analyze := array_append(tables_to_analyze, each_element.table_name);

			EXCEPTION WHEN others THEN
				GET STACKED DIAGNOSTICS error_detail = PG_EXCEPTION_DETAIL;
				RAISE INFO '!! Skipping because of error %. %', SQLERRM, error_detail;
			END;
		END LOOP;

	END IF;

	IF 'indexes' = ANY(elements) THEN

	RAISE INFO 'Enabling Indexes...';

		FOR each_element IN
			select * from relation_element_logs
			WHERE
				element_type = 'index'
			AND CASE WHEN schema_table_list IS NULL THEN TRUE ELSE table_name LIKE ANY(schema_table_list) END -- schema.table
			AND coalesce(element_name = any(element_names_in), TRUE)
			AND enabled_date IS NULL
			ORDER BY id DESC
		LOOP
			IF 'verbose' = any(flags) THEN
				RAISE INFO 'Enabling Index: %.%', each_element.table_name, each_element.element_name;
			END IF;

			BEGIN
				exec_time := clock_timestamp();

				EXECUTE each_element.create_def;

				IF 'verbose' = any(flags) THEN
					RAISE INFO 'Time: %s', date_diff(exec_time, clock_timestamp(), 'second');
				END IF;

				UPDATE relation_element_logs SET
					enabled_date = now()
				WHERE id = each_element.id
				;

				-- add to the list of tables that need to be analyzed at the end
				tables_to_analyze := array_append(tables_to_analyze, each_element.table_name);


			EXCEPTION WHEN others THEN
				GET STACKED DIAGNOSTICS error_detail = PG_EXCEPTION_DETAIL;
				RAISE INFO '!! Skipping constraint because of error %. %', SQLERRM, error_detail;
			END;
		END LOOP;


	END IF;

END CASE;


IF tables_to_analyze IS NOT NULL THEN

	RAISE INFO 'Analyzing ...';

	tables_to_analyze := (SELECT array_agg(DISTINCT unnest) FROM unnest(tables_to_analyze));

	FOREACH each_element.table_name IN ARRAY tables_to_analyze
	LOOP
		IF 'verbose' = any(flags) THEN
			RAISE INFO 'Analyzing Table: %', each_element.table_name;
		END IF;

		BEGIN
			EXECUTE format('ANALYZE %1$s;', each_element.table_name);

		EXCEPTION WHEN others THEN
			GET STACKED DIAGNOSTICS error_detail = PG_EXCEPTION_DETAIL;
			RAISE INFO '!! Skipping constraint because of error %. %', SQLERRM, error_detail;
		END;
	END LOOP;

END IF;

END
$$
LANGUAGE plpgsql
;