CREATE OR REPLACE FUNCTION date_diff
(
	IN start ANYELEMENT
,	IN finish ANYELEMENT
,	IN format TEXT
) RETURNS INT AS
$$
DECLARE
	time_fraction INT;
BEGIN

IF pg_typeof(start) NOT IN (
		'timestamp with time zone'
	,	'timestamp without time zone'
	,	'date'
	)
	THEN RAISE EXCEPTION 'Unaccepted input data type';
END IF
;

time_fraction :=
	CASE format
		WHEN 'second' THEN 1
		WHEN 'minute' THEN 60
		WHEN 'hour' THEN 60*60
		WHEN 'day' THEN 60*60*24
		WHEN 'week' THEN 60*60*24*7
		WHEN 'month' THEN 60*60*24*7*30
		ELSE NULL
	END
;

IF time_fraction IS NULL THEN
	RAISE EXCEPTION 'Invalid reporting format';
END IF;

RETURN EXTRACT(epoch FROM age(finish,start))/time_fraction;

END
$$
LANGUAGE plpgsql
PARALLEL SAFE
IMMUTABLE
;