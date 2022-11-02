CREATE OR REPLACE PROCEDURE raise(
	IN level TEXT
,	IN message TEXT
,	IN is_active BOOLEAN DEFAULT TRUE
) AS
$$
BEGIN

IF is_active THEN

	CASE upper(level)
		WHEN 'DEBUG' THEN
			RAISE DEBUG '%', message;
		WHEN 'LOG' THEN
			RAISE LOG '%', message;
		WHEN 'INFO' THEN
			RAISE INFO '%', message;
		WHEN 'NOTICE' THEN
			RAISE NOTICE '%', message;
		WHEN 'WARNING' THEN
			RAISE WARNING '%', message;
		WHEN 'EXCEPTION' THEN
			RAISE EXCEPTION '%', message;
		ELSE
	END CASE
	;

END IF;

END
$$
LANGUAGE plpgsql
;