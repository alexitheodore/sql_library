CREATE OR REPLACE FUNCTION replace(
	IN haystack TEXT
,	IN needles ANYELEMENT
,	IN wrapper_char TEXT DEFAULT '%'
,	IN clean BOOLEAN DEFAULT FALSE
,	OUT text_out TEXT
) AS
$$
DECLARE
	each_var RECORD;
	text_key TEXT;
	text_value TEXT;
	ql TEXT;
	qr TEXT;
BEGIN

ql := left(wrapper_char, length(wrapper_char)/2);
qr := right(wrapper_char, length(wrapper_char)/2);

/*
USAGE: replaces all occurrences of "needles" names within the "haystack" with the corresponding "needle" values using
the following patterns, depending on the datatype of "needles". Names within the "haystack" string must be wrapped in
the specified "wrapper_char". All needles are case-sensitive.

If "wrapper_char" is one character, then the wrapper is considered to be symmetrical. Otherwise it must be a pair.

- JSON(B): {"name":"value", ...} (top level key-value pairs)
- TEXT[]: [name, value, name, value, ...] (alternating name, value pairs)
- HSTORE: {name => value, ...} (top level key-value pairs)

Example:

SELECT
	replace
	(
		'this is a test of the replacement system %here% and %there%. %here% and %there%.'
	,	'{"here": "abc", "there": 123}'::JSON
-- 	,	'{here, abc, there, 123}'::text[]
-- 	,	'here => abc, there => 123'::HSTORE
	)
;

*/

CASE pg_typeof(needles)::TEXT
	WHEN 'jsonb' THEN
		FOR each_var IN (SELECT * FROM jsonb_each_text(needles)) LOOP

			haystack := replace(haystack, concat(ql,each_var.key,qr), coalesce(each_var.value,''));

		END LOOP
		;
	WHEN 'json' THEN
		FOR each_var IN (SELECT * FROM json_each_text(needles)) LOOP

			haystack := replace(haystack, concat(ql,each_var.key,qr), coalesce(each_var.value,''));

		END LOOP
		;
	WHEN 'text[]' THEN
		FOR text_value IN (SELECT unnest(needles)) LOOP

			IF text_key IS NULL THEN
				text_key := text_value;
			ELSE
				haystack := replace(haystack, concat(ql,text_key,qr), coalesce(text_value, ''));
				text_key := NULL;
			END IF;

		END LOOP
		;
	WHEN 'hstore' THEN
		FOR each_var IN (SELECT * FROM each(needles)) LOOP

			haystack := replace(haystack, concat(ql,each_var.key,qr), coalesce(each_var.value,''));

		END LOOP
		;
	ELSE
	RAISE EXCEPTION '(eid:csqCB) Unsupported "needle" type: must provide either JSON(B), TEXT[] or HSTORE.';
END CASE
;

IF clean THEN haystack := regexp_replace(haystack, concat(ql,'\w*',qr), '', 'g'); END IF;

text_out := haystack;

END
$$
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
;


/*
SELECT
	replace
	(
		'this is a test of the replacement system %here% and %there%. %here% and %there%.'
	,	'{"here": "abc", "there": 123}'::JSON
-- 	,	'{here, abc, there, 123}'::text[]
-- 	,	'here => abc, there => 123'::HSTORE
	)
;
*/