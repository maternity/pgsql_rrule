BEGIN;
SET LOCAL datestyle to ISO, MDY;

-- Ignore fractional seconds on dtstart
SELECT * FROM rrule_expand(
    rrule('FREQ=WEEKLY;COUNT=1'),
    timestamp '2015-01-01 00:00:00.9',
    timestamp '2015-01-02 00:00:00');

-- Ignore fractional seconds on until
SELECT * FROM rrule_expand(
    rrule('FREQ=WEEKLY;COUNT=2'),
    timestamp '2015-01-01 00:00:01',
    timestamp '2015-01-08 00:00:00.9');

ROLLBACK;
