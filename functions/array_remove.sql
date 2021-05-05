CREATE OR REPLACE FUNCTION global.array_remove(
	IN array_left_in anyarray
,	IN array_right_in anyarray
,	OUT array_commons anyarray
) AS
$$
BEGIN

SELECT
	array_agg(array_left.unnest)
INTO array_commons
FROM (SELECT unnest(array_left_in)) array_left
LEFT JOIN (SELECT unnest(array_right_in)) array_right USING (unnest)
WHERE
	array_right IS NULL
;

END;
$$
LANGUAGE plpgsql
;