CREATE OR REPLACE FUNCTION time_trail(
	IN is_active BOOLEAN DEFAULT TRUE
,	OUT microseconds INT
) AS
$$
BEGIN

IF current_setting('time_trail.current_time', TRUE) <> '' AND is_active THEN

	microseconds :=
		EXTRACT(epoch FROM age(
			clock_timestamp()
		,	coalesce(current_setting('time_trail.current_time', TRUE)::TIMESTAMP, clock_timestamp())
		))*1000
		;

END IF;

PERFORM set_config('time_trail.current_time', clock_timestamp()::TEXT, TRUE);

END
$$
LANGUAGE plpgsql
;