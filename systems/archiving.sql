/*
This demos a very simple and robust archiving system which is easy to setup, integrate and scale.



*/


DROP SCHEMA demo1 CASCADE;
CREATE SCHEMA demo1;
SET search_path TO demo1;

CREATE TABLE master (
	master_id SERIAL PRIMARY KEY
,	random_data TEXT
)
;

CREATE TABLE child1 (
	ID SERIAL
,	master_id INT
		REFERENCES master ON UPDATE CASCADE ON DELETE CASCADE
,	random_data TEXT
)
;

CREATE TABLE child2 (
	ID SERIAL
,	master_id INT
		REFERENCES master ON UPDATE CASCADE ON DELETE CASCADE
,	random_data TEXT
)
;

CREATE TABLE archives (
	ID SERIAL PRIMARY KEY
,	TABLE_NAME TEXT
,	archived_columns JSONB
,	DATE TIMESTAMP
		NOT NULL
		DEFAULT now()
,	database_user TEXT
,	transaction_id INT
,	issuing_query TEXT
)
;


CREATE OR REPLACE FUNCTION auto_archive()
	RETURNS TRIGGER AS
$$
BEGIN

INSERT INTO archives 
(
	TABLE_NAME
,	archived_columns
,	database_user
,	transaction_id
,	issuing_query
)
	VALUES
(
	TG_TABLE_NAME
,	row_to_json(OLD.*)
,	CURRENT_USER
,	txid_current()
,	current_query()
)
;

RETURN NULL;

END;
$$
LANGUAGE PLPGSQL
;


CREATE PROCEDURE archive_system_trigger_initializer(IN excluded_tables TEXT[] DEFAULT '{}') AS
$$
DECLARE
	each_table TEXT;
	exec_sql TEXT;

BEGIN

FOR each_table IN (
	SELECT
		DISTINCT
		table_name
	FROM information_schema.columns
	WHERE
		table_name <> 'archives'
	AND NOT ARRAY[table_name::TEXT] <@ excluded_tables
	AND table_schema = CURRENT_SCHEMA()
)
LOOP

exec_sql := '

DROP TRIGGER IF EXISTS auto_archive ON '|| each_table ||';
CREATE TRIGGER auto_archive
    AFTER DELETE ON '|| each_table ||'
    FOR EACH ROW
    EXECUTE FUNCTION auto_archive()
;
'
;

EXECUTE exec_sql;

END LOOP;

END;
$$
LANGUAGE PLPGSQL
;



CALL archive_system_trigger_initializer();
-- CALL archive_system_trigger_initializer(array['child2']); -- give this a shot to see how to declare table to exclude from the automatic archiving function

INSERT INTO master (random_data) VALUES
	('A')
,	('B')
-- RETURNING *
;

INSERT INTO child1 (master_id, random_data)
SELECT
	master_id, now()::TEXT
FROM master
-- RETURNING *
;

INSERT INTO child2 (master_id, random_data)
SELECT
	master_id, now()::TEXT
FROM master
-- RETURNING *
;

DELETE FROM child1;
DELETE FROM master 

WHERE master_id = 1;

-- SELECT * FROM master;
-- SELECT * FROM child1;
SELECT * FROM archives;
