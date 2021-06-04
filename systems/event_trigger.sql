/*

The event trigger below monitors all transactions and is trigger at the successful end of one. All it does is demonstrate the functionality by echoing out a notice with the object_oid's created within the given transaction.

In order to make full use of this, you'll probably need to specify in the event_trigger function what kind of objects you are looking for.

https://www.postgresql.org/docs/current/event-triggers.html

Given the probable use cases of event triggers, keep in mind that they can be disabled/enabled easily with:

https://www.postgresql.org/docs/12/sql-altereventtrigger.html


*/

CREATE OR REPLACE FUNCTION test_event_trigger_for_drops()
        RETURNS event_trigger LANGUAGE plpgsql AS $$
DECLARE
    obj record;
BEGIN
    FOR obj IN (SELECT * FROM pg_event_trigger_ddl_commands())
    LOOP
        RAISE INFO 'object_oid: %, object_type: %', obj.objid, obj.object_type;
    END LOOP;
END
$$;

DROP EVENT TRIGGER IF EXISTS test_event_trigger_for_drops;
CREATE EVENT TRIGGER test_event_trigger_for_drops
   ON ddl_command_end
EXECUTE FUNCTION test_event_trigger_for_drops();

DROP FUNCTION IF EXISTS test();
CREATE OR REPLACE FUNCTION test () RETURNS text AS $$
select 'abc';
$$
LANGUAGE sql
;

CREATE TABLE test (a text PRIMARY KEY);


/*
Another example that prevents a schema from being dropped:
*/


ROLLBACK; BEGIN;

CREATE SCHEMA testst;

CREATE OR REPLACE FUNCTION protect_prod_source_data() RETURNS event_trigger AS
$$
DECLARE
    obj record;
BEGIN
FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
LOOP

	IF obj.object_type = 'schema' and obj.object_name = 'testst' THEN
		RAISE EXCEPTION 'Stop! Are you sure you want to do this? Disable this block with "ALTER EVENT TRIGGER lock_schema DISABLE;" to break everything.';
	END IF;

END LOOP;
END
$$
LANGUAGE plpgsql
;


DROP EVENT TRIGGER IF EXISTS lock_schema;
CREATE EVENT TRIGGER lock_schema
   ON sql_drop
EXECUTE FUNCTION protect_prod_source_data();

DROP SCHEMA testst;

ALTER EVENT TRIGGER lock_schema DISABLE;

DROP SCHEMA testst;