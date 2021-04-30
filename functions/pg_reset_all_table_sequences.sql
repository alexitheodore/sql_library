CREATE OR REPLACE PROCEDURE pg_reset_all_table_sequences(
	IN commit_mode BOOLEAN DEFAULT FALSE
,	IN mask_in TEXT DEFAULT NULL
) AS
$$
DECLARE
	sql_reset TEXT;
	each_sec RECORD;
	new_val TEXT;
BEGIN

sql_reset :=
$sql$
SELECT setval(pg_get_serial_sequence('%1$s.%2$s', '%3$s'), coalesce(max("%3$s"), %4$s), false) FROM %1$s.%2$s;
$sql$
;

FOR each_sec IN (

	SELECT
		quote_ident(table_schema) as table_schema
	,	quote_ident(table_name) as table_name
	,	column_name
	,	coalesce(identity_start::INT, seqstart) as min_val
	FROM information_schema.columns
	JOIN pg_sequence ON seqrelid = pg_get_serial_sequence(quote_ident(table_schema)||'.'||quote_ident(table_name) , column_name)::regclass
	WHERE
		(is_identity::boolean OR column_default LIKE 'nextval%') -- catches both SERIAL and IDENTITY sequences

	-- mask on column address (schema.table.column) if supplied
	AND coalesce( table_schema||'.'||table_name||'.'||column_name = mask_in, TRUE )
)
LOOP

IF commit_mode THEN
	EXECUTE format(sql_reset, each_sec.table_schema, each_sec.table_name, each_sec.column_name, each_sec.min_val) INTO new_val;
	RAISE INFO 'Resetting sequence for: %.% (%) to %'
		,	each_sec.table_schema
		,	each_sec.table_name
		,	each_sec.column_name
		,	new_val
	;
ELSE
	RAISE INFO 'Sequence found for resetting: %.% (%)'
		,	each_sec.table_schema
		,	each_sec.table_name
		,	each_sec.column_name
	;
END IF
;

END LOOP;

END
$$
LANGUAGE plpgsql
;


-- to preview:

call pg_reset_all_table_sequences();

-- to commit:

call pg_reset_all_table_sequences(true);

-- to specify only your target table:

call pg_reset_all_table_sequences('schema.table.column');