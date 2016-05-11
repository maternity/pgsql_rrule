/*
 * Author: The maintainer's name
 * Created at: 2016-05-11 11:15:20 -0400
 *
 */

--
-- This is a example code genereted automaticaly
-- by pgxn-utils.

SET client_min_messages = warning;

BEGIN;

-- You can use this statements as
-- template for your extension.

DROP OPERATOR #? (text, text);
DROP FUNCTION pgsql_rrule(text, text);
DROP TYPE pgsql_rrule CASCADE;
COMMIT;
