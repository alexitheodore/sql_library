/*

Revision History:
06-04-21
 - added in a NULL check which threw an error (and is also an unnecessary operation)
 - completely changed the function - probably way better now, but mainly it is parallel safe
*/


CREATE OR REPLACE FUNCTION array_order(
	IN array_in ANYARRAY
,	IN order_in TEXT DEFAULT 'ASC'
,	OUT array_out ANYARRAY
) AS
$$
BEGIN


CASE upper(order_in)
	WHEN 'ASC'
		THEN
			select
				array_agg(unnest ORDER BY unnest ASC)
			INTO array_out
			from unnest(array_in)
			;
	WHEN 'DESC'
		THEN
			select
				array_agg(unnest ORDER BY unnest DESC)
			INTO array_out
			from unnest(array_in)
			;
	ELSE
		RAISE EXCEPTION '(eid:otsBQ) second argument must be either ASC or DESC';
END CASE
;


END
$$
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
;


/*
SELECT
	array_order('{3,1,10,-1}'::INT[]) = '{-1,1,3,10}'
,	array_order('{z, b, a, 1}'::TEXT[]) = '{1,a,b,z}'
;
*/