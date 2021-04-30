CREATE OR REPLACE FUNCTION full_array_agg_statef
(
	IN array_in_agg anyarray
,	IN array_in anyarray
,	OUT array_out anyarray
) AS $$
BEGIN

array_out := array_in_agg || array_in;

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;


DROP AGGREGATE IF EXISTS full_array_agg (anyarray);
CREATE AGGREGATE full_array_agg(anyarray)
(
	SFUNC = full_array_agg_statef,
	STYPE = anyarray
)
;