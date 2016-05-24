BEGIN;

-- Disallow fractional seconds on dtstart
SELECT * from rrule_expand(
    rrule('FREQ=WEEKLY;COUNT=1'),
    timestamp '2015-01-01 00:00:00.9',
    timestamp '2015-01-02 00:00:00');

ROLLBACK;
