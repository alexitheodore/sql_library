CREATE OR REPLACE FUNCTION array_commonalities(
	IN array_left_in anyarray
,	IN array_right_in anyarray
,	OUT array_commonalities INT
) AS
$$
BEGIN

select
	count(array_left)
into array_commonalities
from unnest(array_left_in) array_left, unnest(array_right_in) array_right
where
	array_left = array_right
;

END;
$$
LANGUAGE plpgsql
;