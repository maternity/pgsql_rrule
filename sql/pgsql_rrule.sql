/*
 * Author: The maintainer's name
 * Created at: 2016-05-11 11:15:20 -0400
 *
 */

--
-- This is a example code genereted automaticaly
-- by pgxn-utils.

SET client_min_messages = warning;

-- If your extension will create a type you can
-- do somenthing like this
CREATE TYPE pgsql_rrule AS ( a text, b text );

-- Maybe you want to create some function, so you can use
-- this as an example
CREATE OR REPLACE FUNCTION pgsql_rrule (text, text)
RETURNS pgsql_rrule LANGUAGE SQL AS 'SELECT ROW($1, $2)::pgsql_rrule';

-- Sometimes it is common to use special operators to
-- work with your new created type, you can create
-- one like the command bellow if it is applicable
-- to your case

CREATE OPERATOR #? (
	LEFTARG   = text,
	RIGHTARG  = text,
	PROCEDURE = pgsql_rrule
);
