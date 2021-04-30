CREATE OR REPLACE FUNCTION array_distinct(
	IN array_in ANYARRAY
,	OUT array_out ANYARRAY
) AS
$$
BEGIN

SELECT
	array_agg(DISTINCT poo)
INTO array_out
FROM unnest(array_in) poo;

END
$$
LANGUAGE plpgsql
PARALLEL SAFE
;