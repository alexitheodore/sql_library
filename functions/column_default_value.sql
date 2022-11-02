/*
The purpose of this function is to be able to produce the default value for any given column as if it were to be gained
by using the "DEFAULT" syntax (which usually can only be used as-is within an INSERT statement).
*/

CREATE OR REPLACE FUNCTION column_default_value(
	IN column_name_in TEXT /* syntax schema.table.column */
,	IN supplied_value ANYELEMENT /* when supplied, skips the default, but also informs the output type */
,	OUT default_out ANYELEMENT
) AS
$$
DECLARE
	sql_exe TEXT;
BEGIN

IF supplied_value IS NULL THEN

	select
		coalesce(typdefault, column_default)
	INTO sql_exe
	FROM information_schema.columns
	LEFT JOIN pg_catalog.pg_type ON domain_name = typname
	WHERE
		column_name = reverse((string_to_array(reverse(column_name_in), '.'))[1])
	AND	concat(table_schema,'.',table_name,'.',column_name) = column_name_in
	;

	EXECUTE 'SELECT '||sql_exe INTO default_out;

ELSE
	default_out := supplied_value;
END IF
;


END
$$
LANGUAGE plpgsql
STABLE
PARALLEL SAFE
;