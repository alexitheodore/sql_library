CREATE OR REPLACE FUNCTION is_set(anyelement) RETURNS BOOLEAN AS
$$
BEGIN
RETURN coalesce($1 <> '', FALSE);
END
$$ LANGUAGE
plpgsql
IMMUTABLE
;