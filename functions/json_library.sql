/*
This is a home-built json extension library. Its something that was started from scratch and needs plenty of work. Some functions are experiments; some are placeholders.
*/

/*

copy symlink via:

$ ln /Volumes/Files/repositories/sql_library/pgs_json_ext/json_library.sql /Volumes/Files/repositories/{path}

*/

\echo '	---- Building JSON Library'

-- some of the sections below require either superuser or ownership privileges - this establishes whether they can be run or not.
SELECT
    greatest(rolsuper, rolname = session_user) as has_privs
from pg_type
join pg_roles on pg_roles.oid = typowner
where typname = 'json'

\gset
;


--> Bookmark  ___FUNCTIONS___
/*

	FUNCTIONS:

*/

CREATE OR REPLACE FUNCTION jsonb_array_append(
    IN  json_base   JSONB
,   IN  json_wedge  JSONB
,   OUT json_out    JSONB
) AS
$$
DECLARE
    wedge TEXT;
    comma TEXT := ',';
BEGIN

CASE
    WHEN jsonb_typeof(json_wedge) = 'string'
        THEN wedge := quote_ident(json_wedge::text);
    WHEN json_wedge IS NULL OR json_wedge::text = '{}' OR json_wedge::text = '[]'
    THEN
        json_out := json_base;
        return;
    WHEN json_base IS NULL OR json_base::text = '{}' OR json_base::text = '[]'
    THEN
        comma := '';
        wedge := json_wedge::text;
    ELSE
        wedge := json_wedge::text;
END CASE;

CASE jsonb_typeof(json_base)::text
    WHEN 'array' THEN
        json_out := (left(json_base::text,-1)+comma+wedge+']')::jsonb
        return;
    WHEN 'object' THEN
        IF jsonb_typeof(json_wedge) = 'array'
            THEN RAISE EXCEPTION '(eid:bRy8S) Cannot append object and array types';
            RETURN;
        END IF;
        json_out := (left(json_base::text,-1)+comma+right(json_wedge::text,-1))::jsonb
        return;
    ELSE
        RAISE EXCEPTION '(eid:GLHQT) Unusual case "%" not found.', jsonb_typeof(json_base)::text;
        RETURN;
END CASE;

END;
$$

LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_array_append(JSONB, JSONB) IS 'Inteligently appends the second argument to the first depending on what datatype the second is.';


/*
*/


/*The native pgs function for json_agg() becomes invalid whenever a NULL or empty array is appended, which is buggy, so I made this patch.*/
CREATE OR REPLACE FUNCTION json_agg_statef (IN json_cur_in JSONB, IN json_next_in JSONB, OUT json_cur_out JSONB) AS
$$
BEGIN
    json_cur_out := json_cur_in & json_next_in;
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;


DROP AGGREGATE IF EXISTS json_agg (JSONB);
CREATE AGGREGATE json_agg (JSONB)
(
    SFUNC = json_agg_statef,
    STYPE = JSONB
)
;
COMMENT ON AGGREGATE json_agg(JSONB) IS 'Replaces the factory-shipped version of this function with one that ignores NULLs and empty objects.';


/*
*/

CREATE OR REPLACE FUNCTION json_agg_array_statef (IN json_cur_in JSONB, IN json_next_in JSONB, OUT json_cur_out JSONB) AS

$$

BEGIN

CASE
WHEN json_cur_in IS NULL THEN
    json_cur_out := json_next_in;
ELSE
    json_cur_out := json_build_array(json_next_in, json_cur_in);
END CASE;

END;

$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;

DROP AGGREGATE IF EXISTS json_agg_array (JSONB);
CREATE AGGREGATE json_agg_array (JSONB)
(
    SFUNC = json_agg_array_statef,
    STYPE = JSONB
)
;
COMMENT ON FUNCTION json_agg_array(JSONB) IS 'Safely aggregates json using the standard json_build_array() function but ignoring NULL objects.';


/*
*/




CREATE OR REPLACE FUNCTION json_setrsert(IN JSONB, IN TEXT[], IN ANYELEMENT, IN BOOLEAN DEFAULT TRUE) RETURNS JSONB AS
$$

BEGIN

IF ($1 #> $2) IS NULL
	THEN return jsonb_set(COALESCE($1,'{}'), $2[(cardinality($2)-1)], to_jsonb(array[$3]), TRUE);
	ELSE return jsonb_insert($1, $2, to_jsonb($3), $4);
END IF;

END;
$$

LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION json_setrsert(JSONB, TEXT[], ANYELEMENT, BOOLEAN) IS 'Inserts a value into the array of the first argument at the destination designated by the second argument. It creates the array if it does not exist already. This is a combination of the native functions jsonb_set and jsonb_insert';


/*
*/

CREATE OR REPLACE FUNCTION jsonb_table_insert(
    IN  target_schema   TEXT
,   IN  target_table    TEXT
,   IN  update_values   JSONB
,   IN  flags           JSONB    DEFAULT '{}'
,   OUT json_out        JSONB
)
AS
$$
DECLARE
    exec_string TEXT;
BEGIN

with
    table_props as
(
select
    column_name::text
,   udt_name::text
,   data_type::text
from information_schema.columns
where
    table_name = target_table
and table_schema = target_schema
)

,   insert_data as
(
select
    key as column_name
,   value as column_value
from jsonb_each_text(update_values)
)

,   build as
(
select
    string_agg(column_name, ', ') as column_name_list
,   string_agg(quote_literal(column_value)::text || (CASE WHEN data_type = 'ARRAY' THEN '::JSONB'::text ELSE ''::TEXT END) || '::' || udt_name, ', ') as column_value_list
from insert_data
join table_props using (column_name)    -- only the columns supplied in the JSON object will be pulled from the destination table
)

SELECT
        'INSERT INTO ' || target_schema || '.' || target_table
    ||  ' (' || column_name_list || ')'
    ||  ' VALUES (' || column_value_list ||')'
    ||  ' RETURNING row_to_json(' || target_table || ')'
    into exec_string
FROM build
;

IF flags->?'debug' THEN
    json_out := 'sql'+> exec_string; RETURN;
END IF;

EXECUTE exec_string into json_out;

END;
$$
LANGUAGE PLPGSQL
VOLATILE
;

COMMENT ON FUNCTION jsonb_table_insert(TEXT, TEXT, JSONB, JSONB) IS 'Emulates a single-row table insert query using json where the supplied object keys correspond to the destination table column names. The first argument is the destination schema, the second argument is the destination table, the third argument is the json with values for columns (invalid column names are ignored) and the fourth argument is for diagnostic flags. The response is the newly added row.';



/*
*/

CREATE OR REPLACE FUNCTION jsonb_table_update(
    IN  target_schema   TEXT
,   IN  target_table    TEXT
,   IN  target_row      JSONB
,   IN  update_values   JSONB
,   IN  flags           JSONB    DEFAULT '{}'
,   OUT json_out        JSONB
)
AS
$$
DECLARE
    exec_string TEXT;
BEGIN

with
    table_props as
(
select
    column_name::text
,   udt_name::text
,   data_type::text
from information_schema.columns
where
    table_name = target_table
and table_schema = target_schema
)

,   insert_data as
(
select
    key as column_name
,   value as column_value
from jsonb_each_text(update_values)
)

,   build as
(
select
    string_agg(
        column_name || ' = ' || COALESCE(
            quote_literal(column_value) || (CASE WHEN data_type = 'ARRAY' THEN '::JSONB'::text ELSE ''::TEXT END) || '::' || udt_name
        ,   'NULL' -- for when when the value is actually NULL
        )
    ,   ', '
    ) as data_list
from insert_data
join table_props using (column_name)    -- only the columns supplied in the JSON object will be pulled from the destination table
)
,   wheres as
(
select
    string_agg(key || ' = ' || quote_literal(value), ' and ') as wheres
from jsonb_each_text(target_row)
)

SELECT
    'UPDATE ' || target_schema || '.' || target_table || ' SET ' || data_list || ' WHERE ' || wheres ||  ' RETURNING row_to_json(' || target_table || ')'
    into exec_string
FROM build, wheres
;

IF flags->?'debug' THEN
    json_out := 'sql'+> exec_string; return;
END IF;

EXECUTE exec_string INTO json_out;

END;
$$

LANGUAGE PLPGSQL
VOLATILE
;

COMMENT ON FUNCTION jsonb_table_update(TEXT, TEXT, JSONB, JSONB, JSONB) IS 'Emulates a single-row table update query using json where the supplied object keys correspond to the destination table column names. The first argument is the destination schema, the second argument is the destination table, the third argument is the json object to specify the where constraints, the fourth argument is the json object with values for updated columns (invalid column names are ignored) and the fith argument is for diagnostic flags. The response is the newly added row.';



CREATE OR REPLACE FUNCTION jsonb_keys_coexist(
    IN  value_in    JSONB
,   IN  keys        TEXT[]
)
RETURNS BOOLEAN AS
$$
BEGIN

RETURN
(
SELECT
    count(*) > 1
FROM jsonb_object_keys(value_in)
WHERE
    jsonb_object_keys <@ keys
)
;

END;
$$

LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_keys_coexist(JSONB, TEXT[]) IS 'This is a shorthand operator that Returns TRUE if *more than one* of the specified keys in the second argument exists at the top level of the first argument.';


/*
*/

CREATE OR REPLACE FUNCTION jsonb_delta(
    IN json_left JSONB
,   IN json_right JSONB
,   OUT json_out JSONB
) AS
$$
BEGIN

-- IF json_left IS NULL OR json_right IS NULL THEN
-- 	RAISE EXCEPTION 'Non-null inputs required';
-- END IF
-- ;

WITH
    base as
(
SELECT
    key
,   CASE
		WHEN a.value IS DISTINCT FROM b.value THEN jsonb_build_object('left', a.value, 'right', b.value)
		ELSE NULL
	END as changes
FROM jsonb_each_text(json_left) a
FULL OUTER JOIN jsonb_each_text(json_right) b using (key)
)
SELECT
    jsonb_object_agg(key,changes)
INTO json_out
FROM base
WHERE
    changes IS NOT NULL
;

json_out := coalesce(json_out, '{}');

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_delta(JSONB, JSONB) IS 'Computes a diff between the first and second JSONB arguments.';

/*
*/

DROP TYPE IF EXISTS key_value CASCADE;
CREATE TYPE key_value AS
(
    key     TEXT
,   value   TEXT
)
;


CREATE OR REPLACE FUNCTION jsonb_each_casted(
    IN json_in JSONB
) RETURNS SETOF key_value AS
$$
DECLARE
BEGIN

RETURN QUERY
select
    key
,   CASE
        WHEN jsonb_typeof(jbe.value) = 'array' THEN replace(replace(jbet.value::text,'[','{'),']','}')
        WHEN jsonb_typeof(jbe.value) = 'string' THEN jbet.value
        WHEN jsonb_typeof(jbe.value) = 'null' THEN NULL
        ELSE jbet.value
    END
from jsonb_each(json_in) jbe
join jsonb_each_text(json_in) jbet using (key)
;

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_each_casted(JSONB) IS 'System function used for casting.';


CREATE OR REPLACE FUNCTION required_keys(
	IN json_in JSONB
,	IN keys TEXT[]
) RETURNS void AS
$$
DECLARE
BEGIN


IF NOT json_in ?& keys THEN
	RAISE EXCEPTION '(eid:BqOQt) Insufficient arguments, missing parameters: %'
	,	(
		select
			string_agg(required_keys, ', ')
		from jsonb_object_keys(json_in) available_keys
		right JOIN unnest(keys) required_keys ON available_keys=required_keys
		WHERE
			available_keys IS NULL
	);
END IF;


END
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_each_casted(JSONB) IS 'Raises an error whenever the specified keys are not provided in the input json';


/*
*/


CREATE OR REPLACE FUNCTION jsonb_strip_blanks(
	IN json_in JSONB
,	OUT json_out JSONB
) AS
$$
BEGIN

json_out := replace(json_in::text, '""', 'null');

json_out := jsonb_strip_nulls(json_out);

json_out := regexp_replace(json_out::text, '(,?)(\s*)({})(,?)(\s*)', '', 'g');

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_strip_blanks(JSONB) IS 'Removes all keys that have blank or null values.';




--> Bookmark  ___CASTS___
\if :has_privs
/*

	CASTS:

*/

CREATE OR REPLACE FUNCTION "text"(IN json_in JSONB) returns TEXT as
$$
SELECT (json_in#>>'{}')::TEXT;
$$
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE;
COMMENT ON FUNCTION "text"(JSONB) IS 'System function used for casting';
DROP CAST IF EXISTS (JSONB AS TEXT);
CREATE CAST (JSONB AS TEXT) WITH FUNCTION "text"(JSONB) AS ASSIGNMENT;


CREATE OR REPLACE FUNCTION text_array(IN json_array JSONB) returns TEXT[] as
$$
SELECT ARRAY(SELECT jsonb_array_elements_text(json_array));
$$
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE;
COMMENT ON FUNCTION text_array(JSONB) IS 'System function used for casting';
DROP CAST IF EXISTS (JSONB AS text[]);
CREATE CAST (JSONB AS text[]) WITH FUNCTION text_array(JSONB) AS ASSIGNMENT;


/*
-- this seems to be upgraded over

CREATE OR REPLACE FUNCTION "int"(IN json_in JSONB) returns INT as
$$
SELECT (json_in#>>'{}')::INT;
$$
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE;
COMMENT ON FUNCTION "int"(JSONB) IS 'System function used for casting';
DROP CAST IF EXISTS (JSONB AS int);
CREATE CAST (JSONB AS int) WITH FUNCTION "int"(JSONB) AS ASSIGNMENT;

*/


CREATE OR REPLACE FUNCTION int_array(IN json_array JSONB) returns INT[] as
$$
SELECT ARRAY(SELECT jsonb_array_elements_text(json_array)::int);
$$
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE;
COMMENT ON FUNCTION int_array(JSONB) IS 'System function used for casting';
DROP CAST IF EXISTS (JSONB AS int[]);
CREATE CAST (JSONB AS int[]) WITH FUNCTION int_array(JSONB) AS ASSIGNMENT;


/*

CREATE OR REPLACE FUNCTION "numeric"(IN json_in JSONB) returns NUMERIC as
$$
SELECT (json_in#>>'{}')::NUMERIC;
$$
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE;
COMMENT ON FUNCTION "numeric"(JSONB) IS 'System function used for casting';
DROP CAST IF EXISTS (JSONB AS NUMERIC);
CREATE CAST (JSONB AS NUMERIC) WITH FUNCTION "numeric"(JSONB) AS ASSIGNMENT;

*/


\endif


--> Bookmark  ___OPERATORS___
/*

	OPERATORS:

*/


CREATE OR REPLACE FUNCTION json_select_keys_if_exist( -- selects multiple keys
    IN  json_in     JSONB
,   IN  key_list    TEXT[]
,   OUT json_out    JSONB
)

AS

$$
DECLARE
    key_name TEXT;
BEGIN

FOREACH key_name IN ARRAY key_list LOOP

    IF json_in ? key_name THEN
        json_out := json_out & (json_in # key_name);
    END IF;

END LOOP;

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;

COMMENT ON FUNCTION json_select_keys_if_exist(JSONB, TEXT[]) IS 'Returns the object for the given key name(s) text array from the given JSONB array. This function is intended to be used by custom operator(s).';
-- separate function than "json_select_key_if_exists()" because combining them requires a polymorphic input and that requires usage to explicitly cast variables which is a pain


DROP OPERATOR IF EXISTS #& (JSONB, TEXT[]);
CREATE OPERATOR #& (
    PROCEDURE = json_select_keys_if_exist
,   LEFTARG = JSONB
,   RIGHTARG = TEXT[]
)
;
COMMENT ON OPERATOR #& (JSONB, TEXT[]) IS 'This is a shorthand operator that returns the top-level key-value pairs in left object which are mentioned in the right key-name text array.';

/*
*/


CREATE OR REPLACE FUNCTION json_select_key_if_exists( -- selects one key
    IN  json_in     JSONB
,   IN  json_key    TEXT
,   OUT json_out    JSONB
)

AS

$$
DECLARE

BEGIN

CASE
    WHEN json_in ? json_key
    THEN
        json_out := (json_key +> (json_in #> array[json_key]));
        RETURN;
    ELSE
        json_out := NULL;
        RETURN;
END CASE;


END;
$$

LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION json_select_key_if_exists(JSONB, TEXT) IS 'Returns the object for the given key name from the given JSONB array. This function is intended to be used by custom operator(s).';


DROP OPERATOR IF EXISTS # (JSONB, text);
CREATE OPERATOR # (
    PROCEDURE = json_select_key_if_exists
,   LEFTARG = JSONB
,   RIGHTARG = text
)
;
COMMENT ON OPERATOR # (JSONB, TEXT) IS 'This is a shorthand operator that returns the top-level key-value pair in left object of the right key-name text.';



/*
*/

-- This function differs from that of the pgs native || functionality in that for (this function) if either constitiutent is NULL, then the result is just the other constituent. This makes it easy to append without needing to know whether the appended object is NULL or not.

CREATE OR REPLACE FUNCTION json_append(
    IN  json_a      JSONB
,   IN  json_b      JSONB
,   OUT json_out    JSONB
)
AS $$
DECLARE
    json_empty JSONB := '{}'::JSONB;
BEGIN

    json_out := COALESCE(json_a,json_empty) || COALESCE(json_b,json_empty);

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;


COMMENT ON FUNCTION json_append(JSONB, JSONB) IS 'Replaces the factory-shipped version of this function with one that ignores NULLs and empty objects.';


DROP OPERATOR IF EXISTS & (JSONB, JSONB);
CREATE OPERATOR & (
    PROCEDURE = json_append
,   LEFTARG = JSONB
,   RIGHTARG = JSONB
)
;
COMMENT ON OPERATOR & (JSONB, JSONB) IS 'This is a shorthand operator that appends the left JSONB object to the right JSONB object.';

/*
*/

-- DROP FUNCTION IF EXISTS is_set(JSONB, TEXT);
CREATE OR REPLACE FUNCTION is_set(
    IN  json_in		JSONB
,   IN  key_name	TEXT
,   OUT is_set		BOOLEAN
)
AS $$
DECLARE
    json_empty JSONB := '{}'::JSONB;
BEGIN

IF 		(json_in ? key_name)
	AND coalesce(
			NOT json_in ->> key_name IN ('', '[]')
		,	NOT json_in ->> key_name IS NULL
		,	TRUE
		)
	THEN
	is_set := TRUE;
ELSE
	is_set := FALSE;
END IF;

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;


DROP OPERATOR IF EXISTS ?* (JSONB, TEXT);
CREATE OPERATOR ?* (
    PROCEDURE = is_set
,   LEFTARG = JSONB
,   RIGHTARG = TEXT
)
;
COMMENT ON OPERATOR ?* (JSONB, TEXT) IS 'This is a shorthand operator that checks whether the specified key exists AND has a non-empty value.';



/*
*/


CREATE OR REPLACE FUNCTION jsonb_as_numeric(
	IN 	json_in 	JSONB
,	IN 	key_in 		TEXT
,	OUT	json_out	NUMERIC
)
AS
$$
BEGIN
-- todo: add error handling if casting cannot be done successfully
    json_out := (json_in->>key_in)::NUMERIC;
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_as_numeric(JSONB, TEXT) IS 'Gets value from object cast as NUMERIC. This function is intended to be used by custom operator(s).';

DROP OPERATOR IF EXISTS ->## (jsonb, text);
CREATE OPERATOR ->## (
    PROCEDURE = jsonb_as_numeric,
    LEFTARG = jsonb,
    RIGHTARG = text,
    COMMUTATOR = ->##
)
;
COMMENT ON OPERATOR ->## (JSONB, TEXT) IS 'This is a shorthand operator that returns the numeric value from the left object per the key given by right operator.';

/*
*/

CREATE OR REPLACE FUNCTION jsonb_as_int(
	IN 	json_in 	JSONB
,	IN 	key_in 		TEXT
,	OUT	json_out	INT
)
AS
$$
BEGIN
-- todo: add error handling if casting cannot be done successfully
    json_out := (json_in->>key_in)::INT;
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_as_int(JSONB, TEXT) IS 'This is a shorthand operator that gets value from object cast as INT. This function is intended to be used by custom operator(s).';


DROP OPERATOR IF EXISTS -># (jsonb, text);
CREATE OPERATOR -># (
    PROCEDURE = jsonb_as_int,
    LEFTARG = jsonb,
    RIGHTARG = text,
    COMMUTATOR = ->#
)
;
COMMENT ON OPERATOR -># (JSONB, TEXT) IS 'This is a shorthand operator that returns the integer value from the left object per the key given by right operator.';

/*
*/

-- this differs from the next one in that it converts a JSONB which contains an array to a text[] by specifying the key. eg '{"cheese": ["a", "b", "c"]}' ->& 'cheese => '{a,b,c}'

CREATE OR REPLACE FUNCTION jsonb_key_as_text_array(
    IN  json_in     JSONB
,   IN  key_in      TEXT
,   OUT text_out    TEXT[]
)
AS
$$
BEGIN

select
    array_agg(j_array)
into text_out
FROM (SELECT jsonb_array_elements_text(json_in->key_in) as j_array) poo
;

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_key_as_text_array(JSONB, TEXT) IS 'This is a shorthand operator that gets value from object cast as TEXT[]. This function is intended to be used by custom operator(s).';


DROP OPERATOR IF EXISTS ->& (jsonb, text);
CREATE OPERATOR ->& (
    PROCEDURE = jsonb_key_as_text_array,
    LEFTARG = jsonb,
    RIGHTARG = text
)
;
COMMENT ON OPERATOR ->& (JSONB, TEXT) IS 'This is a shorthand operator that returns the text array from the left ARRAY per the key given by right operator.';


/*
*/

-- this differs from the previous one in that it converts a JSONB array to a text[] without a key. eg '["a", "b", "c"]'->>& => '{a,b,c}'

CREATE OR REPLACE FUNCTION jsonb_array_as_text_array(
    IN  json_in     JSONB
,   OUT text_out    TEXT[]
)
AS
$$
BEGIN

select
    array_agg(j_array)
into text_out
FROM (SELECT jsonb_array_elements_text(json_in) as j_array) poo
;

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_array_as_text_array(JSONB) IS 'This is a shorthand operator that gets value from object cast as TEXT[]. This function is intended to be used by custom operator(s).';


DROP OPERATOR IF EXISTS ->>& (jsonb, NONE);
CREATE OPERATOR ->>& (
    PROCEDURE = jsonb_array_as_text_array,
    LEFTARG = jsonb
)
;
COMMENT ON OPERATOR ->>& (JSONB, NONE) IS 'This is a shorthand operator that returns the text array from the left ARRAY per the key given by right operator.';


/*
*/

CREATE OR REPLACE FUNCTION jsonb_as_boolean(
	IN 	json_in 	JSONB
,	IN 	key_in 		TEXT
,	OUT	json_out	BOOLEAN
)
AS
$$
BEGIN
    json_out := (json_in->>key_in)::BOOLEAN;
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_as_boolean(JSONB, TEXT) IS 'This is a shorthand operator that gets value from object cast as BOOLEAN. This function is intended to be used by custom operator(s).';


DROP OPERATOR IF EXISTS ->? (jsonb, text);
CREATE OPERATOR ->? (
    PROCEDURE = jsonb_as_boolean,
    LEFTARG = jsonb,
    RIGHTARG = text,
    COMMUTATOR = ->?
)
;
COMMENT ON OPERATOR ->? (JSONB, TEXT) IS 'This is a shorthand operator that returns the boolean value from the left object per the key given by right operator.';

/*
*/

CREATE OR REPLACE FUNCTION jsonb_as_date(
	IN 	json_in 	JSONB
,	IN 	key_in 		TEXT
,	OUT	json_out	DATE
)
AS
$$
BEGIN
    json_out := (json_in->>key_in)::date;
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_as_date(JSONB, TEXT) IS 'This is a shorthand operator that gets value from object cast as DATE. This function is intended to be used by custom operator(s).';


DROP OPERATOR IF EXISTS ->@ (jsonb, text);
CREATE OPERATOR ->@ (
    PROCEDURE = jsonb_as_date,
    LEFTARG = jsonb,
    RIGHTARG = text,
    COMMUTATOR = ->@
)
;
COMMENT ON OPERATOR ->@ (JSONB, TEXT) IS 'This is a shorthand operator that returns the date from the left object per the key given by right operator.';

/*
*/

CREATE OR REPLACE FUNCTION jsonb_build(
	IN 	key_in 		text
,	IN 	value_in 	anyelement
,	OUT	json_out	JSONB
)
AS
$$
BEGIN
    json_out := jsonb_build_object(key_in,value_in);
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_build(TEXT, ANYELEMENT) IS 'Builds JSONB from TEXT and ANYELEMENT. This function is intended to be used by custom operator(s).';

DROP OPERATOR IF EXISTS +> (text, anyelement); -- though this takes "anyelement", text and JSON types will first be matched with their dedicated functions for proper handling. Everything else gets this function.
CREATE OPERATOR +> (
    PROCEDURE = jsonb_build,
    LEFTARG = text,
    RIGHTARG = anyelement,
    COMMUTATOR = +>
)
;
COMMENT ON OPERATOR +> (TEXT, ANYELEMENT) IS 'This is a shorthand operator that builds a JSONB object from the left key and right value.';

/*
*/

CREATE OR REPLACE FUNCTION jsonb_build(
	IN 	key_in 		text
,	IN 	value_in 	text
,	OUT	json_out	JSONB
)
AS
$$
BEGIN
    json_out := jsonb_build_object(key_in,value_in);
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_build(TEXT, TEXT) IS 'Builds JSONB from TEXT and TEXT. This function is intended to be used by custom operator(s).';


DROP OPERATOR IF EXISTS +> (text, text);
CREATE OPERATOR +> (
    PROCEDURE = jsonb_build,
    LEFTARG = text,
    RIGHTARG = text,
    COMMUTATOR = +>
)
;
COMMENT ON OPERATOR +> (TEXT, TEXT) IS 'This is a shorthand operator that builds a JSONB object from the left key and right text.';

/*
*/

CREATE OR REPLACE FUNCTION jsonb_build(
	IN 	key_in 		TEXT
,	IN 	value_in 	JSONB
,	OUT	json_out	JSONB
)
AS
$$
BEGIN
    json_out := jsonb_build_object(key_in,value_in);
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION jsonb_build(TEXT, JSONB) IS 'Builds JSONB from TEXT and JSONB. This function is intended to be used by custom operator(s).';


DROP OPERATOR IF EXISTS +> (text, jsonb);
CREATE OPERATOR +> (
    PROCEDURE = jsonb_build,
    LEFTARG = text,
    RIGHTARG = jsonb,
    COMMUTATOR = +>
)
;
COMMENT ON OPERATOR +> (TEXT, JSONB) IS 'This is a shorthand operator that builds a JSONB object from the left key and right JSONB.';



/*
*/


CREATE OR REPLACE FUNCTION int_array(IN json_in JSONB, IN int_in TEXT) returns INT[] as
$$

SELECT ARRAY(SELECT jsonb_array_elements_text(json_in->int_in)::int);

$$
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE;

COMMENT ON FUNCTION int_array(JSONB, TEXT) IS 'Gets value from object cast as INT[]. This function is intended to be used by custom operator(s).';

DROP OPERATOR IF EXISTS ->#& (jsonb, text);
CREATE OPERATOR ->#& (
    PROCEDURE = "int_array",
    LEFTARG = JSONB,
    RIGHTARG = TEXT,
    COMMUTATOR = ->#&
)
;
COMMENT ON OPERATOR ->#& (JSONB, TEXT) IS 'Returns the integer array value from the left object per the key given by right operator.';

/*
*/

DROP OPERATOR IF EXISTS ** (jsonb, none);
CREATE OPERATOR ** (
    PROCEDURE = jsonb_pretty
,   LEFTARG = jsonb
)
;
COMMENT ON OPERATOR ** (JSONB, NONE) IS 'This is a shorthand operator that returns the left object made pretty.';


/*
*/


CREATE OR REPLACE FUNCTION jsonb_accepted_keys(
    IN  value_in    JSONB
,   IN  keys        TEXT[]
)
RETURNS BOOLEAN AS
$$
BEGIN

RETURN
(
SELECT
    count(*)= 0
FROM jsonb_object_keys(value_in)
WHERE
    NOT array[jsonb_object_keys] <@ keys
)
;

END;
$$

LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;

COMMENT ON FUNCTION jsonb_accepted_keys(JSONB, TEXT[]) IS 'Returns false if any of the keys provided in the first JSON argument are not in the second TEXT[] argument (in otherwords: unaccepted).';

DROP OPERATOR IF EXISTS ?&! (JSONB, TEXT[]);
CREATE OPERATOR ?&! (
    PROCEDURE = jsonb_accepted_keys,
    LEFTARG = JSONB,
    RIGHTARG = TEXT[]
)
;
COMMENT ON OPERATOR ?&! (JSONB, TEXT[]) IS 'This is a shorthand operator that returns FALSE if any of the keys provided in the left object are not specified in the left text array.';



/*
*/


CREATE OR REPLACE FUNCTION cast_to_jsonb(IN TEXT) RETURNS JSONB AS
$$
BEGIN
    return $1::jsonb;
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
PARALLEL SAFE
;
COMMENT ON FUNCTION cast_to_jsonb(TEXT) IS 'System function used for casting';

DROP OPERATOR IF EXISTS @ (none, TEXT);
CREATE OPERATOR @ (
    PROCEDURE = cast_to_jsonb,
    RIGHTARG = TEXT
)
;
COMMENT ON OPERATOR @ (NONE, TEXT) IS 'This is a shorthand operator that casts the right text into JSONB.';



/*
*/

\if :has_privs

CREATE OR REPLACE VIEW json_operators AS

WITH
    ops AS
(
SELECT
    *
FROM pg_operator
)
,   pgta AS
(
SELECT
    oid AS oprresult
,   typname
FROM pg_type
)
,   pgtr AS
(
SELECT
    oid AS oprright
,   typname AS right_type
FROM pg_type
)
,   pgtl AS
(
SELECT
    oid AS oprleft
,   typname AS left_type
FROM pg_type
)

SELECT
    oprname AS OPERATOR
,   left_type
,   right_type
,   typname AS return_type
,   COALESCE('('||left_type||')','') ||' '|| oprname ||' '|| COALESCE('('||right_type||')','') ||' '|| '-->' ||' '|| typname AS formula
,   obj_description(ops.oid) AS description
,   oprcode AS operator_function
FROM ops
LEFT JOIN pgtr USING (oprright)
LEFT JOIN pgtl USING (oprleft)
JOIN pgta USING (oprresult)
WHERE
    ARRAY[left_type, right_type]::TEXT[] && ARRAY['json', 'jsonb']
ORDER BY left_type, right_type, return_type
;

\endif