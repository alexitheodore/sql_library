CREATE OR REPLACE FUNCTION array_order(
	IN array_in ANYARRAY
,	IN order_in TEXT DEFAULT 'ASC'
,	OUT array_out ANYARRAY
) AS
$$
BEGIN

IF upper(order_in) NOT IN ('ASC', 'DESC')
	THEN RAISE EXCEPTION 'second argument must be either ASC or DESC';
END IF
;

EXECUTE
	format(
			$sql$select array_agg(unnest ORDER BY unnest %1$s) from unnest('%2$s'::%3$s);$sql$
		,	order_in
		,	array_in
		,	pg_typeof(array_in)
		)
INTO array_out
;

END
$$
LANGUAGE plpgsql
;