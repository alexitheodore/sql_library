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


/* Until pg13 becomes standard, the "OR REPLACE" syntax cannot be used and this silly workaround is necessary. */
-->
\out /dev/null
SELECT to_regproc('first') IS NULL AS needed;
\gset \out \if :needed
--<

-- And then wrap an aggregate around it
CREATE AGGREGATE first (
	sfunc = first_agg
,	basetype = anyelement
,	stype = anyelement
)
;

\endif