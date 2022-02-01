DO
$$
DECLARE
	each_ext TEXT;
BEGIN

FOR each_ext IN (SELECT extname FROM pg_extension) LOOP
	EXECUTE format('DROP EXTENSION "%1$s" CASCADE;', each_ext);
END LOOP
;

END
$$
LANGUAGE plpgsql
;