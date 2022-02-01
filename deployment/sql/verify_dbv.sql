CREATE OR REPLACE PROCEDURE verify_dbv(dbv_id_in INT DEFAULT 0, schema_in TEXT DEFAULT NULL)
AS
$$
DECLARE
	dbv_delta INT;
	dbv_id_current INT;
BEGIN

schema_in := coalesce(schema_in||'.', '');

EXECUTE format('SELECT max(dbv_id) FROM %sdeployment_logs', schema_in) INTO dbv_id_current;

IF coalesce( dbv_id_current <> (dbv_id_in - 1), TRUE )
THEN
	RAISE EXCEPTION '❌ Wrong version. Current dbv_id: %, attempting to build to %', dbv_id_current, dbv_id_in;
ELSE
	RAISE INFO 'ℹ️ Current dbv_id: %, transferring data to %', dbv_id_current, dbv_id_in;
END IF;

END
$$
LANGUAGE plpgsql
;