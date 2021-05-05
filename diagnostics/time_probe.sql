create or replace function time_probe(message TEXT, enabled BOOLEAN DEFAULT FALSE)
RETURNS VOID AS
$$
<<abc>>
BEGIN

IF enabled IS FALSE THEN RETURN; EXIT abc; END IF;


RAISE INFO '%ms %'
	,	date_part('epoch', clock_timestamp() - statement_timestamp()) * 1000
	,	message
;

end;
$$
LANGUAGE plpgsql
VOLATILE
;