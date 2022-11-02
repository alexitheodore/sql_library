CREATE OR REPLACE FUNCTION stack_trace(
	IN trace_on BOOLEAN
,	IN message_in TEXT
,	IN delimiter TEXT DEFAULT chr(10)
,	OUT message_out TEXT
) AS
$$
BEGIN

IF trace_on
THEN

	IF message_in IS NOT NULL THEN

		message_in := array_append(
						nullif(current_setting('stack_trace.text', TRUE), '')::TEXT[]
					,	format('(%1$s) %2$s', clock_timestamp(), message_in)
					)::TEXT
		;

		PERFORM
			set_config(
				'stack_trace.text'
			,	message_in
			,	TRUE
			);

	ELSE
		message_out := array_to_string(nullif(current_setting('stack_trace.text', TRUE), '')::TEXT[], delimiter);
	END IF
	;


END IF
;

END
$$
LANGUAGE plpgsql
CALLED ON NULL INPUT
;

/*
SELECT
	stack_trace(TRUE, 'test1')
,	stack_trace(TRUE, 'test2')
,	stack_trace(FALSE, 'test3')
,	stack_trace(TRUE, NULL::TEXT)
;
*/

CREATE OR REPLACE FUNCTION stack_trace(
	IN trace_on BOOLEAN
,	IN json_in JSONB
,	OUT json_out JSONB
) AS
$$
BEGIN

IF trace_on THEN

	IF json_in IS NOT NULL THEN

		PERFORM
			set_config(
				'stack_trace.json'
			,	(
					coalesce(nullif(current_setting('stack_trace.json', TRUE), ''), '[]')::JSONB
				||	jsonb_build_array(
						jsonb_build_object(
							'timestamp', clock_timestamp()
						) || json_in
					)
				)::TEXT
			,	TRUE
			);
	ELSE
		json_out := coalesce(nullif(current_setting('stack_trace.json', TRUE), ''), '[]')::JSONB;
	END IF
	;

END IF;



END
$$
LANGUAGE plpgsql
CALLED ON NULL INPUT
;



/*
SELECT
	stack_trace(TRUE, '{"action":"asdsd"}'::JSONB)**
,	stack_trace(TRUE, @'{"action":"cscxx"}')**
,	stack_trace(FALSE, @'{"action":"sdssds"}')
,	stack_trace(TRUE, NULL::JSONB)**
;
*/