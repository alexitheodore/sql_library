-- This makes it easy to insert INTs into INT[] columns without lots of manual casting.

CREATE OR REPLACE FUNCTION int_to_int_array(INT) returns INT[] as
$$
SELECT ARRAY[$1];
$$
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE;

COMMENT ON FUNCTION int_to_int_array(INT) IS 'System function used for casting';

DROP CAST IF EXISTS (INT AS INT[]);
CREATE CAST (INT AS INT[]) WITH FUNCTION int_to_int_array(INT) AS ASSIGNMENT;