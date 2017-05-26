-- Query to roughly count the number of objects in the user defined schema.
-- This doesn't take all nuances into account, but should return a count within
-- the right order of magnitude.
--
-- Written as a VIEW for easy aggregations like for example:
--
--		select object, sum(objects) from catalogsize group by 1;
--
CREATE VIEW catalogsize AS
(
SELECT
	CASE
		WHEN relkind = 'v' THEN 'view'
		WHEN relkind = 'S' THEN 'sequence'
		WHEN relkind = 'i' THEN 'index'
		ELSE 'relation' END AS object,
	CASE
		WHEN relstorage = 'h' THEN 'heap'
		WHEN relstorage = 'a' THEN 'ao'
		WHEN relstorage = 'c' THEN 'aocs'
		WHEN relstorage = 'x' THEN 'external'
		WHEN relstorage = 'v' THEN 'virtual'
		ELSE ''
	END
	|| ' ' ||
	CASE
		WHEN relkind = 'r' THEN 'relation'
		WHEN relkind = 'i' THEN 'index'
		WHEN relkind = 't' THEN 'toastrelation'
		WHEN relkind = 'v' THEN 'view'
		WHEN relkind = 'S' THEN 'sequence'
		ELSE 'other'
	END
	|| ' ' ||
	CASE WHEN (reltoastrelid > 0) THEN 'toasted' ELSE '' END AS object_type,
	count(*) AS objects
FROM
	pg_catalog.pg_class c
		JOIN pg_catalog.pg_namespace n ON (c.relnamespace = n.oid)
WHERE
	n.nspname NOT IN ('pg_catalog', 'pg_aoseg', 'information_schema', 'gp_toolkit')
	AND c.relkind IN ('r', 'i', 't', 'v', 'S')
GROUP BY
	1, 2
ORDER BY
	2 DESC
)
UNION ALL
(
SELECT
	'type' AS object,
	CASE
		WHEN typtype = 'b' THEN 'base type'
		WHEN typtype = 'c' THEN 'composite type'
		WHEN typtype = 'd' THEN 'domain type'
		WHEN typtype = 'e' THEN 'enum type'
		WHEN typtype = 'p' THEN 'pseudo type'
	END AS object_type,
	count(*) AS objects
FROM
	pg_catalog.pg_type t
		JOIN pg_catalog.pg_namespace n ON (t.typnamespace = n.oid)
WHERE
	n.nspname NOT IN ('pg_catalog', 'pg_aoseg', 'information_schema', 'gp_toolkit')
GROUP BY
	1, 2
)
UNION ALL
(
SELECT
	'constraint' AS object,
	CASE
		WHEN contype = 'c' THEN 'check constraint'
		WHEN contype = 'u' THEN 'unique constraint'
		WHEN contype = 'p' THEN 'primary key'
		WHEN contype = 'f' THEN 'foreign key'
	END AS object_type,
	count(*) AS objects
FROM
	pg_catalog.pg_constraint c
		JOIN pg_catalog.pg_namespace n ON (c.connamespace = n.oid)
WHERE
	n.nspname NOT IN ('pg_catalog', 'pg_aoseg', 'information_schema', 'gp_toolkit')
GROUP BY
	1, 2
)
UNION ALL
(
SELECT
	'role' AS object,
	CASE WHEN rolsuper THEN 'superuser' ELSE 'normal' END AS object_type,
	count(*) AS objects
FROM
	pg_catalog.pg_roles r
GROUP BY
	1, 2
)
UNION ALL
(
SELECT
	'function' AS object,
	l.lanname AS object_type,
	count(*) AS objects
FROM
	pg_catalog.pg_proc f
		JOIN pg_catalog.pg_namespace n ON (f.pronamespace = n.oid)
		JOIN pg_catalog.pg_language l ON (f.prolang = l.oid) 
WHERE
	n.nspname NOT IN ('pg_catalog', 'pg_aoseg', 'information_schema', 'gp_toolkit')
GROUP BY
	1, 2
)
UNION ALL
(
SELECT
	'cast' AS object,
	CASE
		WHEN castcontext = 'i' THEN 'implicit cast'
		WHEN castcontext = 'e' THEN 'explicit cast'
		WHEN castcontext = 'a' THEN 'assignment'
	END AS object_type,
	count(*) AS objects
FROM
	pg_catalog.pg_cast
GROUP BY
	1, 2
)
UNION ALL
(
SELECT
	'aggregate' AS object,
	CASE WHEN aggordered THEN 'ordered' ELSE 'normal' END AS object_type,
	count(*) AS objects
FROM
	pg_catalog.pg_aggregate a
		JOIN pg_catalog.pg_proc p ON (a.aggfnoid::oid = p.oid)
		JOIN pg_catalog.pg_namespace n ON (p.pronamespace = n.oid)
WHERE
	n.nspname NOT IN ('pg_catalog', 'pg_aoseg', 'information_schema', 'gp_toolkit')
GROUP BY
	1, 2
)
UNION ALL
(
SELECT
	'attribute' AS object,
	'column' AS object_type,
	count(*) AS objects
FROM
	pg_catalog.pg_attribute a
		JOIN pg_catalog.pg_class c ON (a.attrelid = c.oid)
		JOIN pg_catalog.pg_namespace n ON (c.relnamespace = n.oid)
WHERE
	n.nspname NOT IN ('pg_catalog', 'pg_aoseg', 'information_schema', 'gp_toolkit')
)
;
