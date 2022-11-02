CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION generate_custom_uuid (
	in length INT
,	in for_table text
,	in for_column text
,	OUT next_id TEXT
) AS
$$
DECLARE
	id_is_used BOOLEAN;
	loop_count INT := 0;
	characters TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
	loop_length INT;
BEGIN

LOOP
	next_id := '';
	loop_length := 0;
	WHILE loop_length < length LOOP
    next_id := next_id || substr(characters, get_byte(gen_random_bytes(length), loop_length) % length(characters) + 1, 1);
    loop_length := loop_length + 1;
  	END LOOP;

	EXECUTE format('SELECT TRUE FROM %s WHERE %s = %s LIMIT 1', for_table, for_column, quote_literal(next_id)) into id_is_used;

	EXIT WHEN id_is_used IS NULL;

	loop_count := loop_count + 1;

	IF loop_count > 100 THEN
		RAISE EXCEPTION '(eid:oGqZg) Too many loops. Might be reaching the practical limit for the given length.';
	END IF;
END LOOP;


END
$$
LANGUAGE plpgsql
STABLE
;

DROP TABLE some_table;
CREATE TABLE some_table (
	id
		TEXT
		DEFAULT generate_custom_uuid(4, 'some_table', 'id')
		PRIMARY KEY
)
;


-- to test performance, use this and adjust the loop count exit point
DO
$$
DECLARE
	loop_count INT := 0;

BEGIN

BEGIN

	-- WHILE LOOP
	WHILE loop_count < 100000
	LOOP

		INSERT INTO some_table VALUES (DEFAULT);
		loop_count := loop_count + 1;
	END LOOP;

EXCEPTION
	WHEN OTHERS THEN
	RAISE EXCEPTION '(eid:KSNcC) exited on loop %', loop_count;

END;

END
$$ LANGUAGE plpgsql
;

select * from some_table;
