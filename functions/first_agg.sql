CREATE OR REPLACE FUNCTION global.first_agg ( anyelement, anyelement )
RETURNS anyelement AS
$$
	SELECT $1;
$$
LANGUAGE SQL
IMMUTABLE
STRICT
PARALLEL SAFE
;

-- And then wrap an aggregate around it
CREATE OR REPLACE AGGREGATE first (
	sfunc = first_agg
,	basetype = anyelement
,	stype = anyelement
)
;
