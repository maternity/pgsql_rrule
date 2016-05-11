\set ECHO 0
BEGIN;
\i sql/pgsql_rrule.sql
\set ECHO all

-- You should write your tests

SELECT pgsql_rrule('foo', 'bar');

SELECT 'foo' #? 'bar' AS arrowop;

CREATE TABLE ab (
    a_field pgsql_rrule
);

INSERT INTO ab VALUES('foo' #? 'bar');
SELECT (a_field).a, (a_field).b FROM ab;

SELECT (pgsql_rrule('foo', 'bar')).a;
SELECT (pgsql_rrule('foo', 'bar')).b;

SELECT ('foo' #? 'bar').a;
SELECT ('foo' #? 'bar').b;

ROLLBACK;
