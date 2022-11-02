/*
Supplements the conventional `concat()` function by providing an optional delimiter. First field is the delimiter.
*/

CREATE OR REPLACE FUNCTION concat_(delimiter TEXT, VARIADIC args TEXT[]) RETURNS TEXT AS
$$
BEGIN

delimiter := coalesce(delimiter, ' ');

RETURN array_to_string(args, delimiter);

END
$$
LANGUAGE plpgsql
;