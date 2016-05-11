BEGIN;

-- rrule_weekday
SELECT rrule_weekday('SU'), rrule_weekday(0), dow('SU'::rrule_weekday);
SELECT rrule_weekday('MO'), rrule_weekday(1), dow('MO'::rrule_weekday);
SELECT rrule_weekday('TU'), rrule_weekday(2), dow('TU'::rrule_weekday);
SELECT rrule_weekday('WE'), rrule_weekday(3), dow('WE'::rrule_weekday);
SELECT rrule_weekday('TH'), rrule_weekday(4), dow('TH'::rrule_weekday);
SELECT rrule_weekday('FR'), rrule_weekday(5), dow('FR'::rrule_weekday);
SELECT rrule_weekday('SA'), rrule_weekday(6), dow('SA'::rrule_weekday);

-- sortable
SELECT * FROM unnest('{TU,TH,SA,SU,MO,WE,FR}'::rrule_weekday[]) ORDER BY 1;

-- rrule_weekdaynum
SELECT * FROM rrule_weekdaynum('TU');
SELECT * FROM rrule_weekdaynum('2TU');
SELECT * FROM rrule_weekdaynum('-2TU');

-- rrule_freq
SELECT * FROM rrule_freq('SECONDLY');
SELECT * FROM rrule_freq('MINUTELY');
SELECT * FROM rrule_freq('HOURLY');
SELECT * FROM rrule_freq('DAILY');
SELECT * FROM rrule_freq('WEEKLY');
SELECT * FROM rrule_freq('MONTHLY');
SELECT * FROM rrule_freq('YEARLY');

-- rrule
SELECT * FROM rrule('FREQ=WEEKLY;BYDAY=MO,WE,FR');


ROLLBACK;
