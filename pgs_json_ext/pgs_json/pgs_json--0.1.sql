-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION base36" to load this file. \quit
CREATE OR REPLACE FUNCTION jsonb_build(
  IN  key_in    text
, IN  value_in  anyelement
, OUT json_out  JSONB
) 
AS
$$
BEGIN
    json_out := jsonb_build_object(key_in,value_in);
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
;