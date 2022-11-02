CREATE OR REPLACE PROCEDURE flush_connections(
	IN database_name TEXT
)
AS
$$
BEGIN

PERFORM
	pg_terminate_backend(pid) AS terminated
FROM pg_stat_activity
WHERE
	datname = database_name
AND	pid <> pg_backend_pid()
;

END
$$
LANGUAGE plpgsql
;


