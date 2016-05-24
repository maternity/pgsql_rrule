CREATE TYPE rrule_freq AS ENUM (
    'SECONDLY',
    'MINUTELY',
    'HOURLY',
    'DAILY',
    'WEEKLY',
    'MONTHLY',
    'YEARLY'
);

CREATE TYPE rrule_weekday AS ENUM ('SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA');
CREATE FUNCTION rrule_weekday(dow integer) RETURNS rrule_weekday
    LANGUAGE sql IMMUTABLE
    AS $$
-- rrule_weekday(2) => 'TU'::rrule_weekday
VALUES(CASE dow
    WHEN 0 THEN 'SU'::rrule_weekday
    WHEN 1 THEN 'MO'::rrule_weekday
    WHEN 2 THEN 'TU'::rrule_weekday
    WHEN 3 THEN 'WE'::rrule_weekday
    WHEN 4 THEN 'TH'::rrule_weekday
    WHEN 5 THEN 'FR'::rrule_weekday
    WHEN 6 THEN 'SA'::rrule_weekday
END);
$$;
CREATE FUNCTION dow(day rrule_weekday) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
VALUES(CASE day
    WHEN 'SU' THEN 0
    WHEN 'MO' THEN 1
    WHEN 'TU' THEN 2
    WHEN 'WE' THEN 3
    WHEN 'TH' THEN 4
    WHEN 'FR' THEN 5
    WHEN 'SA' THEN 6
END);
$$;

CREATE TYPE rrule_weekdaynum AS (week integer, day rrule_weekday);
CREATE FUNCTION rrule_weekdaynum(raw text) RETURNS rrule_weekdaynum
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
-- rrule_weekdaynum('TU') => '(,TU)'::rrule_weekdaynum
-- rrule_weekdaynum('2TU') => '(2,TU)'::rrule_weekdaynum
DECLARE
    parsed rrule_weekdaynum;
    field text;
BEGIN
    parsed.week = substring(raw from '^((?:\+|-)?\d+)?\w\w$');
    IF parsed.week IS NOT NULL AND parsed.week NOT BETWEEN -53 AND -1 AND parsed.week NOT BETWEEN 1 AND 53 THEN
        RAISE EXCEPTION 'Invalid weekdaynum=%.', raw;
    END IF;
    parsed.day = upper(substring(raw from '^(?:(?:\+|-)?\d+)?(\w\w)$'));
    IF parsed.day IS NULL THEN RAISE EXCEPTION 'Invalid weekdaynum=%.', raw; END IF;
    RETURN parsed;
END;
$_$;

-- CREATE FUNCTION rrule_weekdaynum(dow integer) RETURNS
--     rrule_weekdaynum
--     LANGUAGE sql IMMUTABLE
--     AS $$
-- -- rrule_weekdaynum(2) => '(,TU)'::rrule_weekdaynum
-- VALUES((NULL,rrule_weekday(dow))::rrule_weekdaynum);
-- $$;

CREATE TYPE rrule AS (
	freq rrule_freq,
	until text,
	count integer,
	"interval" integer,
	bysecond integer[],
	byminute integer[],
	byhour integer[],
	byday rrule_weekdaynum[],
	bymonthday integer[],
	byyearday integer[],
	byweekno integer[],
	bymonth integer[],
	bysetpos integer[],
	wkst rrule_weekday
);


CREATE FUNCTION rrule(raw text) RETURNS rrule
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    parsed rrule;
    part text;
    field text;
    value text;
    ivalues integer[];
BEGIN
    -- NOTE: Validation here deals with wellformedness and correctness wrt
    -- RFC-5545.

    FOREACH part IN ARRAY regexp_split_to_array(raw, ';') LOOP
        field = substring(part from '^(\w+)=');
        IF field IS NULL THEN
            RAISE EXCEPTION 'Malformed rrule part %.', part;
        END IF;
        value = substring(part from '^\w+=(.*)');

        CASE upper(field)
        WHEN 'FREQ' THEN
            -- freq rrule_freq
            -- validation by enum
            parsed.freq = upper(value);

        WHEN 'UNTIL' THEN
            -- until text
            --                        / ( "UNTIL" "=" enddate )
            --
            --   enddate     = date / date-time
            --
            --   date-time  = date "T" time ;As specified in the DATE and TIME
            --                              ;value definitions
            --
            --   date               = date-value
            --
            --   date-value         = date-fullyear date-month date-mday
            --   date-fullyear      = 4DIGIT
            --   date-month         = 2DIGIT        ;01-12
            --   date-mday          = 2DIGIT        ;01-28, 01-29, 01-30, 01-31
            --                                      ;based on month/year
            --
            --   time         = time-hour time-minute time-second [time-utc]
            --
            --   time-hour    = 2DIGIT        ;00-23
            --   time-minute  = 2DIGIT        ;00-59
            --   time-second  = 2DIGIT        ;00-60
            --   ;The "60" value is used to account for positive "leap" seconds.
            --
            --   time-utc     = "Z"
            IF value !~ '^\d{8}(?:T\d{6}Z?)?$' THEN RAISE EXCEPTION 'Invalid UNTIL=%.', value; END IF;
            parsed.until = value;

        WHEN 'COUNT' THEN
            -- count integer
            --                        / ( "COUNT" "=" 1*DIGIT )
            IF value !~ '^\d+$' THEN RAISE EXCEPTION 'Invalid COUNT=%.', value; END IF;
            parsed.count = value;

        WHEN 'INTERVAL' THEN
            -- interval integer
            --                        / ( "INTERVAL" "=" 1*DIGIT )
            IF value !~ '^\d+$' THEN RAISE EXCEPTION 'Invalid INTERVAL=%.', value; END IF;
            parsed.interval = value;

        WHEN 'BYSECOND' THEN
            -- bysecond integer[]
            --                        / ( "BYSECOND" "=" byseclist )
            --   byseclist   = ( seconds *("," seconds) )
            --   seconds     = 1*2DIGIT       ;0 to 60
            ivalues = regexp_split_to_array(value, ',');
            IF 0 > ANY(ivalues) OR 60 < ANY(ivalues) THEN RAISE EXCEPTION 'Invalid BYSECOND=%.', value; END IF;
            parsed.bysecond = ivalues;

        WHEN 'BYMINUTE' THEN
            -- byminute integer[]
            --                        / ( "BYMINUTE" "=" byminlist )
            --   byminlist   = ( minutes *("," minutes) )
            --   minutes     = 1*2DIGIT       ;0 to 59
            ivalues = regexp_split_to_array(value, ',');
            IF 0 > ANY(ivalues) OR 59 < ANY(ivalues) THEN RAISE EXCEPTION 'Invalid BYMINUTE=%.', value; END IF;
            parsed.byminute = ivalues;

        WHEN 'BYHOUR' THEN
            -- byhour integer[]
            --                        / ( "BYHOUR" "=" byhrlist )
            --   byhrlist    = ( hour *("," hour) )
            --   hour        = 1*2DIGIT       ;0 to 23
            ivalues = regexp_split_to_array(value, ',');
            IF 0 > ANY(ivalues) OR 23 < ANY(ivalues) THEN RAISE EXCEPTION 'Invalid BYHOUR=%.', value; END IF;
            parsed.byhour = ivalues;

        WHEN 'BYDAY' THEN
            -- byday rrule_weekdaynum[]
            --                        / ( "BYDAY" "=" bywdaylist )
            --   bywdaylist  = ( weekdaynum *("," weekdaynum) )
            --   weekdaynum  = [[plus / minus] ordwk] weekday
            --   plus        = "+"
            --   minus       = "-"
            --   ordwk       = 1*2DIGIT       ;1 to 53
            --   weekday     = "SU" / "MO" / "TU" / "WE" / "TH" / "FR" / "SA"
            FOREACH value IN ARRAY regexp_split_to_array(value, ',') LOOP
                parsed.byday = array_append(parsed.byday, rrule_weekdaynum(value));
            END LOOP;

        WHEN 'BYMONTHDAY' THEN
            -- bymonthday integer[]
            --                        / ( "BYMONTHDAY" "=" bymodaylist )
            --   bymodaylist = ( monthdaynum *("," monthdaynum) )
            --   monthdaynum = [plus / minus] ordmoday
            --   ordmoday    = 1*2DIGIT       ;1 to 31
            ivalues = regexp_split_to_array(value, ',');
            IF -31 > ANY(ivalues) OR 31 < ANY(ivalues) OR 0 = ANY(ivalues) THEN RAISE EXCEPTION 'Invalid BYMONTHDAY=%.', value; END IF;
            parsed.bymonthday = ivalues;

        WHEN 'BYYEARDAY' THEN
            -- byyearday integer[]
            --                        / ( "BYYEARDAY" "=" byyrdaylist )
            --   byyrdaylist = ( yeardaynum *("," yeardaynum) )
            --   yeardaynum  = [plus / minus] ordyrday
            --   ordyrday    = 1*3DIGIT      ;1 to 366
            ivalues = regexp_split_to_array(value, ',');
            IF -366 > ANY(ivalues) OR 366 < ANY(ivalues) OR 0 = ANY(ivalues) THEN RAISE EXCEPTION 'Invalid BYYEARDAY=%.', value; END IF;
            parsed.byyearday = ivalues;

        WHEN 'BYWEEKNO' THEN
            -- byweekno integer[]
            --                        / ( "BYWEEKNO" "=" bywknolist )
            --   bywknolist  = ( weeknum *("," weeknum) )
            --   weeknum     = [plus / minus] ordwk
            ivalues = regexp_split_to_array(value, ',');
            IF -53 > ANY(ivalues) OR 53 < ANY(ivalues) OR 0 = ANY(ivalues) THEN RAISE EXCEPTION 'Invalid BYWEEKNO=%.', value; END IF;
            parsed.byweekno = ivalues;

        WHEN 'BYMONTH' THEN
            -- bymonth integer[]
            --                        / ( "BYMONTH" "=" bymolist )
            --   bymolist    = ( monthnum *("," monthnum) )
            --   monthnum    = 1*2DIGIT       ;1 to 12
            ivalues = regexp_split_to_array(value, ',');
            IF 1 > ANY(ivalues) OR 12 < ANY(ivalues) THEN RAISE EXCEPTION 'Invalid BYMONTH=%.', value; END IF;
            parsed.bymonth = ivalues;

        WHEN 'BYSETPOS' THEN
            -- bysetpos integer[]
            --                        / ( "BYSETPOS" "=" bysplist )
            --   bysplist    = ( setposday *("," setposday) )
            --   setposday   = yeardaynum
            ivalues = regexp_split_to_array(value, ',');
            IF -366 > ANY(ivalues) OR 366 < ANY(ivalues) OR 0 = ANY(ivalues) THEN RAISE EXCEPTION 'Invalid BYSETPOS=%.', value; END IF;
            parsed.byyearday = regexp_split_to_array(value, ',');

        WHEN 'WKST' THEN
            -- wkst rrule_weekday
            --                        / ( "WKST" "=" weekday )
            --   weekday     = "SU" / "MO" / "TU" / "WE" / "TH" / "FR" / "SA"
            -- validation by enum
            parsed.wkst = upper(value);

        ELSE
            RAISE EXCEPTION 'Invalid rrule part %.', field;
        END CASE;
    END LOOP;

    --    +----------+--------+--------+-------+-------+------+-------+------+
    --    |          |SECONDLY|MINUTELY|HOURLY |DAILY  |WEEKLY|MONTHLY|YEARLY|
    --    +----------+--------+--------+-------+-------+------+-------+------+
    --    |BYMONTH   |Limit   |Limit   |Limit  |Limit  |Limit |Limit  |Expand|
    --    +----------+--------+--------+-------+-------+------+-------+------+
    --    |BYWEEKNO  |N/A     |N/A     |N/A    |N/A    |N/A   |N/A    |Expand|
    --    +----------+--------+--------+-------+-------+------+-------+------+
    --    |BYYEARDAY |Limit   |Limit   |Limit  |N/A    |N/A   |N/A    |Expand|
    --    +----------+--------+--------+-------+-------+------+-------+------+
    --    |BYMONTHDAY|Limit   |Limit   |Limit  |Limit  |N/A   |Expand |Expand|
    --    +----------+--------+--------+-------+-------+------+-------+------+
    --    |BYDAY     |Limit   |Limit   |Limit  |Limit  |Expand|Note 1 |Note 2|
    --    +----------+--------+--------+-------+-------+------+-------+------+
    --    |BYHOUR    |Limit   |Limit   |Limit  |Expand |Expand|Expand |Expand|
    --    +----------+--------+--------+-------+-------+------+-------+------+
    --    |BYMINUTE  |Limit   |Limit   |Expand |Expand |Expand|Expand |Expand|
    --    +----------+--------+--------+-------+-------+------+-------+------+
    --    |BYSECOND  |Limit   |Expand  |Expand |Expand |Expand|Expand |Expand|
    --    +----------+--------+--------+-------+-------+------+-------+------+
    --    |BYSETPOS  |Limit   |Limit   |Limit  |Limit  |Limit |Limit  |Limit |
    --    +----------+--------+--------+-------+-------+------+-------+------+

    IF parsed.byweekno IS NOT NULL and parsed.freq != 'YEARLY' THEN
        RAISE EXCEPTION 'Invalid % rrule using BYWEEKNO.', parsed.freq;
    END IF;

    IF parsed.byyearday IS NOT NULL and parsed.freq NOT IN ('SECONDLY', 'MINUTELY', 'HOURLY', 'YEARLY') THEN
        RAISE EXCEPTION 'Invalid % rrule using BYYEARDAY.', parsed.freq;
    END IF;

    IF parsed.bymonthday IS NOT NULL and parsed.freq NOT IN ('SECONDLY', 'MINUTELY', 'HOURLY', 'DAILY', 'MONTHLY', 'YEARLY') THEN
        RAISE EXCEPTION 'Invalid % rrule using BYYEARDAY.', parsed.freq;
    END IF;

    IF EXISTS (SELECT 1 FROM unnest(parsed.byday) WHERE week IS NOT NULL) THEN
        -- The BYDAY rule part MUST NOT be specified with a numeric value when
        -- the FREQ rule part is not set to MONTHLY or YEARLY.
        IF parsed.freq NOT IN ('MONTHLY', 'YEARLY') THEN
            RAISE EXCEPTION 'Invalid % rrule using BYDAY having a week index.', parsed.freq;
        END IF;

        -- Furthermore, the BYDAY rule part MUST NOT be specified with a
        -- numeric value with the FREQ rule part set to YEARLY when the
        -- BYWEEKNO rule part is specified.
        IF parsed.freq = 'YEARLY' AND parsed.BYWEEKNO IS NOT NULL THEN
            RAISE EXCEPTION 'Invalid YEARLY rrule using BYWEEKNO and BYDAY having a week index.';
        END IF;
    END IF;

    IF parsed.freq IS NULL THEN
        RAISE EXCEPTION 'Invalid rrule missing FREQ.';
    END IF;
    RETURN parsed;
END;
$_$;

CREATE FUNCTION rrules(raw text[]) RETURNS rrule[]
    LANGUAGE SQL IMMUTABLE
    AS $_$
SELECT array_agg(rrule(rrule)) FROM unnest(raw) rrule(rrule);
$_$;


CREATE FUNCTION rrule_expand(rule rrule, dtstart date, until date) RETURNS TABLE(occurrence date)
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
BEGIN
    rule.byhour = NULL;
    rule.byminute = NULL;
    rule.bysecond = NULL;
    rule.until = rule.until::date;

    RETURN QUERY SELECT rrule_expand(rule, dtstart::timestamp, until::timestamp)::date;
END;
$$;


CREATE FUNCTION rrule_expand(rule rrule, dtstart timestamp without time zone, until timestamp without time zone)
    RETURNS TABLE(occurrence timestamp without time zone)
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    n integer = 0;
    wkst rrule_weekday = COALESCE(rule.wkst, 'MO');
    wksti integer;
BEGIN
-- From https://tools.ietf.org/html/rfc5545#section-3.3.10
--
--       Information, not contained in the rule, necessary to determine the
--       various recurrence instance start time and dates are derived from
--       the Start Time ("DTSTART") component attribute.  For example,
--       "FREQ=YEARLY;BYMONTH=1" doesn't specify a specific day within the
--       month or a time.  This information would be the same as what is
--       specified for "DTSTART".
--
--       BYxxx rule parts modify the recurrence in some manner.  BYxxx rule
--       parts for a period of time that is the same or greater than the
--       frequency generally reduce or limit the number of occurrences of
--       the recurrence generated.  For example, "FREQ=DAILY;BYMONTH=1"
--       reduces the number of recurrence instances from all days (if
--       BYMONTH rule part is not present) to all days in January.  BYxxx
--       rule parts for a period of time less than the frequency generally
--       increase or expand the number of occurrences of the recurrence.
--       For example, "FREQ=YEARLY;BYMONTH=1,2" increases the number of
--       days within the yearly recurrence set from 1 (if BYMONTH rule part
--       is not present) to 2.
--
--       If multiple BYxxx rule parts are specified, then after evaluating
--       the specified FREQ and INTERVAL rule parts, the BYxxx rule parts
--       are applied to the current set of evaluated occurrences in the
--       following order: BYMONTH, BYWEEKNO, BYYEARDAY, BYMONTHDAY, BYDAY,
--       BYHOUR, BYMINUTE, BYSECOND and BYSETPOS; then COUNT and UNTIL are
--       evaluated.
--
--       The table below summarizes the dependency of BYxxx rule part
--       expand or limit behavior on the FREQ rule part value.
--
--       The term "N/A" means that the corresponding BYxxx rule part MUST
--       NOT be used with the corresponding FREQ value.
--
--       BYDAY has some special behavior depending on the FREQ value and
--       this is described in separate notes below the table.
--
--    +----------+--------+--------+-------+-------+------+-------+------+
--    |          |SECONDLY|MINUTELY|HOURLY |DAILY  |WEEKLY|MONTHLY|YEARLY|
--    +----------+--------+--------+-------+-------+------+-------+------+
--    |BYMONTH   |Limit   |Limit   |Limit  |Limit  |Limit |Limit  |Expand|
--    +----------+--------+--------+-------+-------+------+-------+------+
--    |BYWEEKNO  |N/A     |N/A     |N/A    |N/A    |N/A   |N/A    |Expand|
--    +----------+--------+--------+-------+-------+------+-------+------+
--    |BYYEARDAY |Limit   |Limit   |Limit  |N/A    |N/A   |N/A    |Expand|
--    +----------+--------+--------+-------+-------+------+-------+------+
--    |BYMONTHDAY|Limit   |Limit   |Limit  |Limit  |N/A   |Expand |Expand|
--    +----------+--------+--------+-------+-------+------+-------+------+
--    |BYDAY     |Limit   |Limit   |Limit  |Limit  |Expand|Note 1 |Note 2|
--    +----------+--------+--------+-------+-------+------+-------+------+
--    |BYHOUR    |Limit   |Limit   |Limit  |Expand |Expand|Expand |Expand|
--    +----------+--------+--------+-------+-------+------+-------+------+
--    |BYMINUTE  |Limit   |Limit   |Expand |Expand |Expand|Expand |Expand|
--    +----------+--------+--------+-------+-------+------+-------+------+
--    |BYSECOND  |Limit   |Expand  |Expand |Expand |Expand|Expand |Expand|
--    +----------+--------+--------+-------+-------+------+-------+------+
--    |BYSETPOS  |Limit   |Limit   |Limit  |Limit  |Limit |Limit  |Limit |
--    +----------+--------+--------+-------+-------+------+-------+------+
--
--       Note 1:  Limit if BYMONTHDAY is present; otherwise, special expand
--                for MONTHLY.
--
--       Note 2:  Limit if BYYEARDAY or BYMONTHDAY is present; otherwise,
--                special expand for WEEKLY if BYWEEKNO present; otherwise,
--                special expand for MONTHLY if BYMONTH present; otherwise,
--                special expand for YEARLY.

    IF dtstart != date_trunc('second', dtstart) THEN
        -- Fractional seconds on dtstart can cause strange results (e.g.
        -- omission of the first occurrence), and RFC-5545 doesn't allow them,
        -- so the caller must provide an integer for dtstart's seconds.
        RAISE EXCEPTION 'Invalid seconds for dtstart: not an integer';
    END IF;
    until = LEAST(until, rule.until::timestamp);
    wksti = dow(wkst);
    IF extract(dow from dtstart) < wksti THEN
        wksti = wksti-7;
    END IF;

    CASE rule.freq
    WHEN 'WEEKLY' THEN
        -- NOTE: The BYDAY rule part MUST NOT be specified with a numeric value
        --       when the FREQ rule part is not set to MONTHLY or YEARLY.

        IF rule.bysetpos IS NOT NULL THEN
            RAISE EXCEPTION 'Expansion of WEEKLY rrules with BYSETPOS is not implemented.';
        END IF;
        IF rule.interval > 1 THEN
            -- WKST issues
            RAISE EXCEPTION 'Expansion of WEEKLY rrules with INTERVAL > 1 is not implemented.';
        END IF;

        rule.interval = COALESCE(rule.interval, 1);
        rule.byday = COALESCE(rule.byday, array[
            (NULL,rrule_weekday(extract(dow from dtstart)::integer))::rrule_weekdaynum]);
        rule.byhour = COALESCE(rule.byhour, array[extract(hour from dtstart)]);
        rule.byminute = COALESCE(rule.byminute,
            array[extract(minute from dtstart)]);
        rule.bysecond = COALESCE(rule.bysecond,
            array[extract(second from dtstart)]);

        RETURN QUERY
            SELECT ts FROM (

                SELECT
                    week +
                        (dow(day) - wksti)*INTERVAL '1d' +
                        hour*INTERVAL '1h' +
                        minute*INTERVAL '1m' +
                        second*INTERVAL '1s'
                        ts

                FROM
                    generate_series(
                        date_trunc('week', dtstart - INTERVAL '1d'*(wksti-1)) + INTERVAL '1d'*(wksti-1),
                        date_trunc('week', until - INTERVAL '1d'*(wksti-1)) + INTERVAL '1d'*(wksti-1),
                        INTERVAL '1w'*rule.interval) week,
                    (SELECT day FROM unnest(rule.byday)) day(day),
                    unnest(rule.byhour) hour,
                    unnest(rule.byminute) minute,
                    unnest(rule.bysecond) second

                ORDER BY 1

            ) ts(ts)

            WHERE
                (rule.bymonth IS NULL OR extract(month from ts) = ANY(rule.bymonth)) AND
                -- From the second paragraph of page 41 of RFC-5545:
                --     The UNTIL rule part defines a DATE or DATE-TIME value
                --     that bounds the recurrence rule in an inclusive manner.
                -- However, tsrange defaults to exclusion of the upper bound,
                -- so specify that the range is inclusive.
                ts <@ tsrange(dtstart, until, '[]')
                -- TODO: BYSETPOS filter

            LIMIT rule.count;

    ELSE
        RAISE EXCEPTION 'Expansion of % rrules is not implemented.', rule.freq;
    END CASE;
END;
$$;


CREATE FUNCTION get_occurrences(raw text, dtstart date, until date)
    RETURNS date[]
    LANGUAGE SQL
    IMMUTABLE
    AS $$
-- Compatibility with pg_rrule
SELECT array_agg(occurrence) FROM rrule_expand(rrule(raw), dtstart, until);
$$;

CREATE FUNCTION get_occurrences(raw text, dtstart timestamp, until timestamp)
    RETURNS timestamp[]
    LANGUAGE SQL
    IMMUTABLE
    AS $$
-- Compatibility with pg_rrule
SELECT array_agg(occurrence) FROM rrule_expand(rrule(raw), dtstart, until);
$$;

CREATE FUNCTION get_occurrences(rrule rrule, dtstart date, until date)
    RETURNS date[]
    LANGUAGE SQL
    IMMUTABLE
    AS $$
-- Compatibility with pg_rrule
SELECT array_agg(occurrence) FROM rrule_expand(rrule, dtstart, until);
$$;

CREATE FUNCTION get_occurrences(rrule rrule, dtstart timestamp, until timestamp)
    RETURNS timestamp[]
    LANGUAGE SQL
    IMMUTABLE
    AS $$
-- Compatibility with pg_rrule
SELECT array_agg(occurrence) FROM rrule_expand(rrule, dtstart, until);
$$;

CREATE FUNCTION get_freq(raw text)
    RETURNS text
    LANGUAGE SQL
    IMMUTABLE
    AS $$
-- Compatibility with pg_rrule
VALUES((rrule(raw)).freq::text);
$$;

CREATE FUNCTION get_count(raw text)
    RETURNS integer
    LANGUAGE SQL
    IMMUTABLE
    AS $$
-- Compatibility with pg_rrule
VALUES((rrule(raw)).count);
$$;

CREATE FUNCTION get_interval(raw text)
    RETURNS integer
    LANGUAGE SQL
    IMMUTABLE
    AS $$
-- Compatibility with pg_rrule
VALUES((rrule(raw)).interval);
$$;

CREATE FUNCTION get_until(raw text)
    RETURNS text
    LANGUAGE SQL
    IMMUTABLE
    AS $$
-- Compatibility with pg_rrule
VALUES((rrule(raw)).until);
$$;
