BEGIN;

-- Examples from RFC5545 with FREQ=WEEKLY and INTERVAL=1
--
-- Weekly for 10 occurrences:
--
--  ==> (1997 9:00 AM EDT) September 2,9,16,23,30;October 7,14,21
--      (1997 9:00 AM EST) October 28;November 4
SELECT * FROM rrule_expand(
    rrule('FREQ=WEEKLY;COUNT=10'),
    timestamp '19970902T090000',
    timestamp '19970902T090000'+interval '10y');

-- Weekly until December 24, 1997:
--
--  ==> (1997 9:00 AM EDT) September 2,9,16,23,30;
--                         October 7,14,21
--      (1997 9:00 AM EST) October 28;
--                         November 4,11,18,25;
--                         December 2,9,16,23
SELECT rrule_expand(
    rrule('FREQ=WEEKLY;UNTIL=19971224T000000Z'),
    timestamp '19970902T090000',
    timestamp '19970902T090000'+interval '10y');

-- Weekly on Tuesday and Thursday for five weeks:
--
--  ==> (1997 9:00 AM EDT) September 2,4,9,11,16,18,23,25,30;
--                         October 2
SELECT rrule_expand(
    rrule('FREQ=WEEKLY;UNTIL=19971007T000000Z;WKST=SU;BYDAY=TU,TH'),
    timestamp '19970902T090000',
    timestamp '19970902T090000'+interval '10y');
SELECT rrule_expand(
    rrule('FREQ=WEEKLY;COUNT=10;WKST=SU;BYDAY=TU,TH'),
    timestamp '19970902T090000',
    timestamp '19970902T090000'+interval '10y');

ROLLBACK;
