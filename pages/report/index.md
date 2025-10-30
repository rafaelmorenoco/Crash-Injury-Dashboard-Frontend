---
title: Fatalities and Major Injuries Rundown
queries:
   - last_record: last_record.sql
   - age_range: age_range.sql
sidebar_link: false
---

- As of <Value data={last_record} column="latest_record"/> there <Value data={yoy_text_fatal} column="has_have"/> been <Value data={yoy_text_fatal} column="current_year_sum" agg=sum/> **<Value data={yoy_text_fatal} column="fatality"/>** among all road users in <Value data={yoy_text_fatal} column="current_year" fmt='####","'/>   <Value data={yoy_text_fatal} column="difference" agg=sum fmt='####' /> <Value data={yoy_text_fatal} column="difference_text"/> (<Delta data={yoy_text_fatal} column="percentage_change" fmt="+0%;-0%;0%" downIsGood=True neutralMin=-0.00 neutralMax=0.00/>) compared to the same period in <Value data={yoy_text_fatal} column="year_prior" fmt="####."/>
- As of <Value data={last_record} column="latest_record"/> there <Value data={yoy_text_major_injury} column="has_have"/> been <Value data={yoy_text_major_injury} column="current_year_sum" agg=sum/> **<Value data={yoy_text_major_injury} column="major_injury"/>** among all road users in <Value data={yoy_text_major_injury} column="current_year" fmt='####","'/>   <Value data={yoy_text_major_injury} column="difference" agg=sum fmt='####' /> <Value data={yoy_text_major_injury} column="difference_text"/> (<Delta data={yoy_text_major_injury} column="percentage_change" fmt="+0%;-0%;0%" downIsGood=True neutralMin=-0.00 neutralMax=0.00/>) compared to the same period in <Value data={yoy_text_major_injury} column="year_prior" fmt="####."/>


```sql unique_mode
select 
    MODE
from crashes.crashes
group by 1
```

```sql unique_severity
select 
    SEVERITY
from crashes.crashes
group by 1
```

```sql unique_hin
select 
    GIS_ID,
    ROUTENAME
from hin.hin
group by all
```

```sql period_comp_fatal
WITH 
  report_date_range AS (
    SELECT
      CASE 
        WHEN '${inputs.date_range.end}'::DATE 
             >= (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE
        THEN (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE + INTERVAL '1 day'
        ELSE '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
      END   AS end_date,
      '${inputs.date_range.start}'::DATE AS start_date
  ),
  date_info AS (
    SELECT
      start_date,
      end_date,
      CASE
        WHEN start_date = DATE_TRUNC('year', '${inputs.date_range.end}'::DATE)
         AND '${inputs.date_range.end}'::DATE = (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE
        THEN EXTRACT(YEAR FROM '${inputs.date_range.end}'::DATE)::VARCHAR || ' YTD'
        ELSE
          strftime(start_date, '%m/%d/%y')
          || '-'
          || strftime(end_date - INTERVAL '1 day', '%m/%d/%y')
      END AS date_range_label,
      (end_date - start_date) AS date_range_days
    FROM report_date_range
  ),
  offset_period AS (
    SELECT
      start_date,
      end_date,
      CASE 
        WHEN end_date > start_date + INTERVAL '5 year' THEN (SELECT 1/0)  -- guard: >5 yrs
        WHEN end_date > start_date + INTERVAL '4 year' THEN INTERVAL '5 year'
        WHEN end_date > start_date + INTERVAL '3 year' THEN INTERVAL '4 year'
        WHEN end_date > start_date + INTERVAL '2 year' THEN INTERVAL '3 year'
        WHEN end_date > start_date + INTERVAL '1 year' THEN INTERVAL '2 year'
        ELSE INTERVAL '1 year'
      END AS interval_offset
    FROM date_info
  ),
  modes_and_severities AS (
    SELECT DISTINCT MODE
    FROM crashes.crashes
  ),
  current_period AS (
    SELECT 
      MODE,
      SUM(COUNT) AS sum_count
    FROM crashes.crashes
    WHERE
      SEVERITY = 'Fatal'
      AND REPORTDATE BETWEEN
          (SELECT start_date FROM date_info)
        AND
          (SELECT end_date   FROM date_info)
      AND AGE BETWEEN ${inputs.min_age.value}
                  AND (
                    CASE 
                      WHEN ${inputs.min_age.value} <> 0
                       AND ${inputs.max_age.value} = 120
                      THEN 119
                      ELSE ${inputs.max_age.value}
                    END
                  )
    GROUP BY MODE
  ),
  prior_period AS (
    SELECT 
      MODE,
      SUM(COUNT) AS sum_count
    FROM crashes.crashes
    WHERE
      SEVERITY = 'Fatal'
      AND REPORTDATE BETWEEN
          (SELECT start_date     FROM date_info) - (SELECT interval_offset FROM offset_period)
        AND
          (SELECT end_date       FROM date_info) - (SELECT interval_offset FROM offset_period)
      AND AGE BETWEEN ${inputs.min_age.value}
                  AND (
                    CASE 
                      WHEN ${inputs.min_age.value} <> 0
                       AND ${inputs.max_age.value} = 120
                      THEN 119
                      ELSE ${inputs.max_age.value}
                    END
                  )
    GROUP BY MODE
  ),
  total_counts AS (
    SELECT
      SUM(cp.sum_count) AS total_current_period,
      SUM(pp.sum_count) AS total_prior_period
    FROM current_period cp
    FULL JOIN prior_period   pp USING (MODE)
  ),
  prior_date_info AS (
    SELECT
      (SELECT start_date      FROM date_info) - (SELECT interval_offset FROM offset_period) AS prior_start_date,
      (SELECT end_date        FROM date_info) - (SELECT interval_offset FROM offset_period) AS prior_end_date
  ),
  prior_date_label AS (
    SELECT
      CASE
        WHEN (SELECT start_date FROM date_info) = DATE_TRUNC('year', '${inputs.date_range.end}'::DATE)
         AND '${inputs.date_range.end}'::DATE = (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE
        THEN EXTRACT(YEAR FROM prior_end_date)::VARCHAR || ' YTD'
        ELSE
          strftime(prior_start_date,   '%m/%d/%y')
          || '-'
          || strftime(prior_end_date - INTERVAL '1 day', '%m/%d/%y')
      END AS prior_date_range_label
    FROM prior_date_info
  )
SELECT
  mas.MODE,
  COALESCE(cp.sum_count, 0)                           AS current_period_sum,
  COALESCE(pp.sum_count, 0)                           AS prior_period_sum,
  COALESCE(cp.sum_count, 0) - COALESCE(pp.sum_count, 0) AS difference,
  CASE
    WHEN COALESCE(cp.sum_count, 0) = 0 THEN NULL
    WHEN COALESCE(pp.sum_count, 0) != 0 THEN
      (COALESCE(cp.sum_count, 0) - COALESCE(pp.sum_count, 0))
      / COALESCE(pp.sum_count, 0)
    ELSE NULL
  END AS percentage_change,
  (SELECT date_range_label       FROM date_info)       AS current_period_range,
  (SELECT prior_date_range_label FROM prior_date_label) AS prior_period_range,
  (total_current_period - total_prior_period)
    / NULLIF(total_prior_period, 0)                    AS total_percentage_change,
  COALESCE(cp.sum_count, 0)
    / NULLIF(total_current_period, 0)                  AS current_mode_percentage,
  COALESCE(pp.sum_count, 0)
    / NULLIF(total_prior_period, 0)                    AS prior_mode_percentage
FROM modes_and_severities mas
LEFT JOIN current_period cp USING (MODE)
LEFT JOIN prior_period   pp USING (MODE),
     total_counts;
```

```sql barchart_fatal
WITH 
    report_date_range AS (
        SELECT
        CASE 
            WHEN '${inputs.date_range.end}'::DATE 
                >= (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE
            THEN (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE + INTERVAL '1 day'
            ELSE '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
        END   AS end_date,
        '${inputs.date_range.start}'::DATE AS start_date
    ),
    date_info AS (
        SELECT
        start_date,
        end_date,
        CASE
            WHEN start_date = DATE_TRUNC('year', '${inputs.date_range.end}'::DATE)
            AND '${inputs.date_range.end}'::DATE = (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE
            THEN EXTRACT(YEAR FROM '${inputs.date_range.end}'::DATE)::VARCHAR || ' YTD'
            ELSE
            strftime(start_date, '%m/%d/%y')
            || '-'
            || strftime(end_date - INTERVAL '1 day', '%m/%d/%y')
        END AS date_range_label,
        (end_date - start_date) AS date_range_days
        FROM report_date_range
    ),
    offset_period AS (
        SELECT
        start_date,
        end_date,
        CASE 
            WHEN end_date > start_date + INTERVAL '5 year' THEN (SELECT 1/0)  -- guard: >5 yrs
            WHEN end_date > start_date + INTERVAL '4 year' THEN INTERVAL '5 year'
            WHEN end_date > start_date + INTERVAL '3 year' THEN INTERVAL '4 year'
            WHEN end_date > start_date + INTERVAL '2 year' THEN INTERVAL '3 year'
            WHEN end_date > start_date + INTERVAL '1 year' THEN INTERVAL '2 year'
            ELSE INTERVAL '1 year'
        END AS interval_offset
        FROM date_info
    ),
    modes_and_severities AS (
        SELECT DISTINCT 
            MODE
        FROM 
            crashes.crashes
    ), 
    current_period AS (
        SELECT 
            MODE,
            SUM(COUNT) AS sum_count
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY = 'Fatal'
            AND REPORTDATE >= (SELECT start_date FROM date_info)
            AND REPORTDATE <= (SELECT end_date FROM date_info)
            AND AGE BETWEEN ${inputs.min_age.value}
                                AND (
                                    CASE 
                                        WHEN ${inputs.min_age.value} <> 0 
                                        AND ${inputs.max_age.value} = 120
                                        THEN 119
                                        ELSE ${inputs.max_age.value}
                                    END
                                    )
        GROUP BY 
            MODE
    ), 
    prior_period AS (
        SELECT 
            MODE,
            SUM(COUNT) AS sum_count
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY = 'Fatal'
            AND REPORTDATE >= ((SELECT start_date FROM date_info) - (SELECT interval_offset FROM offset_period))
            AND REPORTDATE <= ((SELECT end_date FROM date_info) - (SELECT interval_offset FROM offset_period))
            AND AGE BETWEEN ${inputs.min_age.value}
                                AND (
                                    CASE 
                                        WHEN ${inputs.min_age.value} <> 0 
                                        AND ${inputs.max_age.value} = 120
                                        THEN 119
                                        ELSE ${inputs.max_age.value}
                                    END
                                    )
        GROUP BY 
            MODE
    ), 
    total_counts AS (
        SELECT 
            SUM(cp.sum_count) AS total_current_period,
            SUM(pp.sum_count) AS total_prior_period
        FROM 
            current_period cp
        FULL JOIN 
            prior_period pp 
        ON cp.MODE = pp.MODE
    ),
    prior_date_info AS (
        SELECT
            (SELECT start_date FROM date_info) - (SELECT interval_offset FROM offset_period) AS prior_start_date,
            (SELECT end_date   FROM date_info) - (SELECT interval_offset FROM offset_period) AS prior_end_date
    ),
    prior_date_label AS (
        SELECT
        CASE
            WHEN (SELECT start_date FROM date_info) = DATE_TRUNC('year', '${inputs.date_range.end}'::DATE)
            AND '${inputs.date_range.end}'::DATE = (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE
            THEN EXTRACT(YEAR FROM prior_end_date)::VARCHAR || ' YTD'
            ELSE
            strftime(prior_start_date,   '%m/%d/%y')
            || '-'
            || strftime(prior_end_date - INTERVAL '1 day', '%m/%d/%y')
        END AS prior_date_range_label
        FROM prior_date_info
    )
    SELECT
    mas.MODE,
    'Current Period'    AS period,
    COALESCE(cp.sum_count, 0)         AS period_sum,
    di.date_range_label               AS period_range
    FROM modes_and_severities mas
    LEFT JOIN current_period   cp ON mas.MODE = cp.MODE
    CROSS JOIN date_info       di

    UNION ALL

    SELECT
    mas.MODE,
    'Prior Period'      AS period,
    COALESCE(pp.sum_count, 0)         AS period_sum,
    pdl.prior_date_range_label        AS period_range
    FROM modes_and_severities mas
    LEFT JOIN prior_period     pp ON mas.MODE = pp.MODE
    CROSS JOIN prior_date_label pdl

    ORDER BY mas.MODE, period;
```

```sql period_comp_major
WITH 
  report_date_range AS (
    SELECT
      CASE 
        WHEN '${inputs.date_range.end}'::DATE 
             >= (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE
        THEN (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE + INTERVAL '1 day'
        ELSE '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
      END   AS end_date,
      '${inputs.date_range.start}'::DATE AS start_date
  ),
  date_info AS (
    SELECT
      start_date,
      end_date,
      CASE
        WHEN start_date = DATE_TRUNC('year', '${inputs.date_range.end}'::DATE)
         AND '${inputs.date_range.end}'::DATE = (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE
        THEN EXTRACT(YEAR FROM '${inputs.date_range.end}'::DATE)::VARCHAR || ' YTD'
        ELSE
          strftime(start_date, '%m/%d/%y')
          || '-'
          || strftime(end_date - INTERVAL '1 day', '%m/%d/%y')
      END AS date_range_label,
      (end_date - start_date) AS date_range_days
    FROM report_date_range
  ),
  offset_period AS (
    SELECT
      start_date,
      end_date,
      CASE 
        WHEN end_date > start_date + INTERVAL '5 year' THEN (SELECT 1/0)  -- guard: >5 yrs
        WHEN end_date > start_date + INTERVAL '4 year' THEN INTERVAL '5 year'
        WHEN end_date > start_date + INTERVAL '3 year' THEN INTERVAL '4 year'
        WHEN end_date > start_date + INTERVAL '2 year' THEN INTERVAL '3 year'
        WHEN end_date > start_date + INTERVAL '1 year' THEN INTERVAL '2 year'
        ELSE INTERVAL '1 year'
      END AS interval_offset
    FROM date_info
  ),
  modes_and_severities AS (
    SELECT DISTINCT MODE
    FROM crashes.crashes
  ),
  current_period AS (
    SELECT 
      MODE,
      SUM(COUNT) AS sum_count
    FROM crashes.crashes
    WHERE
      SEVERITY = 'Major'
      AND REPORTDATE BETWEEN
          (SELECT start_date FROM date_info)
        AND
          (SELECT end_date   FROM date_info)
      AND AGE BETWEEN ${inputs.min_age.value}
                  AND (
                    CASE 
                      WHEN ${inputs.min_age.value} <> 0
                       AND ${inputs.max_age.value} = 120
                      THEN 119
                      ELSE ${inputs.max_age.value}
                    END
                  )
    GROUP BY MODE
  ),
  prior_period AS (
    SELECT 
      MODE,
      SUM(COUNT) AS sum_count
    FROM crashes.crashes
    WHERE
      SEVERITY = 'Major'
      AND REPORTDATE BETWEEN
          (SELECT start_date     FROM date_info) - (SELECT interval_offset FROM offset_period)
        AND
          (SELECT end_date       FROM date_info) - (SELECT interval_offset FROM offset_period)
      AND AGE BETWEEN ${inputs.min_age.value}
                  AND (
                    CASE 
                      WHEN ${inputs.min_age.value} <> 0
                       AND ${inputs.max_age.value} = 120
                      THEN 119
                      ELSE ${inputs.max_age.value}
                    END
                  )
    GROUP BY MODE
  ),
  total_counts AS (
    SELECT
      SUM(cp.sum_count) AS total_current_period,
      SUM(pp.sum_count) AS total_prior_period
    FROM current_period cp
    FULL JOIN prior_period   pp USING (MODE)
  ),
  prior_date_info AS (
    SELECT
      (SELECT start_date      FROM date_info) - (SELECT interval_offset FROM offset_period) AS prior_start_date,
      (SELECT end_date        FROM date_info) - (SELECT interval_offset FROM offset_period) AS prior_end_date
  ),
  prior_date_label AS (
    SELECT
      CASE
        WHEN (SELECT start_date FROM date_info) = DATE_TRUNC('year', '${inputs.date_range.end}'::DATE)
         AND '${inputs.date_range.end}'::DATE = (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE
        THEN EXTRACT(YEAR FROM prior_end_date)::VARCHAR || ' YTD'
        ELSE
          strftime(prior_start_date,   '%m/%d/%y')
          || '-'
          || strftime(prior_end_date - INTERVAL '1 day', '%m/%d/%y')
      END AS prior_date_range_label
    FROM prior_date_info
  )
SELECT
  mas.MODE,
  COALESCE(cp.sum_count, 0)                           AS current_period_sum,
  COALESCE(pp.sum_count, 0)                           AS prior_period_sum,
  COALESCE(cp.sum_count, 0) - COALESCE(pp.sum_count, 0) AS difference,
  CASE
    WHEN COALESCE(cp.sum_count, 0) = 0 THEN NULL
    WHEN COALESCE(pp.sum_count, 0) != 0 THEN
      (COALESCE(cp.sum_count, 0) - COALESCE(pp.sum_count, 0))
      / COALESCE(pp.sum_count, 0)
    ELSE NULL
  END AS percentage_change,
  (SELECT date_range_label       FROM date_info)       AS current_period_range,
  (SELECT prior_date_range_label FROM prior_date_label) AS prior_period_range,
  (total_current_period - total_prior_period)
    / NULLIF(total_prior_period, 0)                    AS total_percentage_change,
  COALESCE(cp.sum_count, 0)
    / NULLIF(total_current_period, 0)                  AS current_mode_percentage,
  COALESCE(pp.sum_count, 0)
    / NULLIF(total_prior_period, 0)                    AS prior_mode_percentage
FROM modes_and_severities mas
LEFT JOIN current_period cp USING (MODE)
LEFT JOIN prior_period   pp USING (MODE),
     total_counts;
```

```sql barchart_major
WITH 
    report_date_range AS (
        SELECT
        CASE 
            WHEN '${inputs.date_range.end}'::DATE 
                >= (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE
            THEN (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE + INTERVAL '1 day'
            ELSE '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
        END   AS end_date,
        '${inputs.date_range.start}'::DATE AS start_date
    ),
    date_info AS (
        SELECT
        start_date,
        end_date,
        CASE
            WHEN start_date = DATE_TRUNC('year', '${inputs.date_range.end}'::DATE)
            AND '${inputs.date_range.end}'::DATE = (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE
            THEN EXTRACT(YEAR FROM '${inputs.date_range.end}'::DATE)::VARCHAR || ' YTD'
            ELSE
            strftime(start_date, '%m/%d/%y')
            || '-'
            || strftime(end_date - INTERVAL '1 day', '%m/%d/%y')
        END AS date_range_label,
        (end_date - start_date) AS date_range_days
        FROM report_date_range
    ),
    offset_period AS (
        SELECT
        start_date,
        end_date,
        CASE 
            WHEN end_date > start_date + INTERVAL '5 year' THEN (SELECT 1/0)  -- guard: >5 yrs
            WHEN end_date > start_date + INTERVAL '4 year' THEN INTERVAL '5 year'
            WHEN end_date > start_date + INTERVAL '3 year' THEN INTERVAL '4 year'
            WHEN end_date > start_date + INTERVAL '2 year' THEN INTERVAL '3 year'
            WHEN end_date > start_date + INTERVAL '1 year' THEN INTERVAL '2 year'
            ELSE INTERVAL '1 year'
        END AS interval_offset
        FROM date_info
    ),
    modes_and_severities AS (
        SELECT DISTINCT 
            MODE
        FROM 
            crashes.crashes
    ), 
    current_period AS (
        SELECT 
            MODE,
            SUM(COUNT) AS sum_count
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY = 'Major'
            AND REPORTDATE >= (SELECT start_date FROM date_info)
            AND REPORTDATE <= (SELECT end_date FROM date_info)
            AND AGE BETWEEN ${inputs.min_age.value}
                                AND (
                                    CASE 
                                        WHEN ${inputs.min_age.value} <> 0 
                                        AND ${inputs.max_age.value} = 120
                                        THEN 119
                                        ELSE ${inputs.max_age.value}
                                    END
                                    )
        GROUP BY 
            MODE
    ), 
    prior_period AS (
        SELECT 
            MODE,
            SUM(COUNT) AS sum_count
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY = 'Major'
            AND REPORTDATE >= ((SELECT start_date FROM date_info) - (SELECT interval_offset FROM offset_period))
            AND REPORTDATE <= ((SELECT end_date FROM date_info) - (SELECT interval_offset FROM offset_period))
            AND AGE BETWEEN ${inputs.min_age.value}
                                AND (
                                    CASE 
                                        WHEN ${inputs.min_age.value} <> 0 
                                        AND ${inputs.max_age.value} = 120
                                        THEN 119
                                        ELSE ${inputs.max_age.value}
                                    END
                                    )
        GROUP BY 
            MODE
    ), 
    total_counts AS (
        SELECT 
            SUM(cp.sum_count) AS total_current_period,
            SUM(pp.sum_count) AS total_prior_period
        FROM 
            current_period cp
        FULL JOIN 
            prior_period pp 
        ON cp.MODE = pp.MODE
    ),
    prior_date_info AS (
        SELECT
            (SELECT start_date FROM date_info) - (SELECT interval_offset FROM offset_period) AS prior_start_date,
            (SELECT end_date   FROM date_info) - (SELECT interval_offset FROM offset_period) AS prior_end_date
    ),
    prior_date_label AS (
        SELECT
        CASE
            WHEN (SELECT start_date FROM date_info) = DATE_TRUNC('year', '${inputs.date_range.end}'::DATE)
            AND '${inputs.date_range.end}'::DATE = (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE
            THEN EXTRACT(YEAR FROM prior_end_date)::VARCHAR || ' YTD'
            ELSE
            strftime(prior_start_date,   '%m/%d/%y')
            || '-'
            || strftime(prior_end_date - INTERVAL '1 day', '%m/%d/%y')
        END AS prior_date_range_label
        FROM prior_date_info
    )
    SELECT
    mas.MODE,
    'Current Period'    AS period,
    COALESCE(cp.sum_count, 0)         AS period_sum,
    di.date_range_label               AS period_range
    FROM modes_and_severities mas
    LEFT JOIN current_period   cp ON mas.MODE = cp.MODE
    CROSS JOIN date_info       di

    UNION ALL

    SELECT
    mas.MODE,
    'Prior Period'      AS period,
    COALESCE(pp.sum_count, 0)         AS period_sum,
    pdl.prior_date_range_label        AS period_range
    FROM modes_and_severities mas
    LEFT JOIN prior_period     pp ON mas.MODE = pp.MODE
    CROSS JOIN prior_date_label pdl

    ORDER BY mas.MODE, period;
```

```sql yoy_text_fatal
WITH date_range AS (
    SELECT
        MAX(REPORTDATE)::DATE + INTERVAL '1 day' AS max_report_date
    FROM
        crashes.crashes
),
params AS (
    SELECT
        date_trunc('year', dr.max_report_date) AS current_year_start,
        dr.max_report_date AS current_year_end,
        date_trunc('year', dr.max_report_date - interval '1 year') AS prior_year_start,
        dr.max_report_date - interval '1 year' AS prior_year_end,
        extract(year FROM dr.max_report_date) AS current_year,
        extract(year FROM dr.max_report_date - interval '1 year') AS year_prior
    FROM
        date_range dr
),
yearly_counts AS (
    SELECT
        SUM(CASE
            WHEN cr.REPORTDATE BETWEEN p.current_year_start AND p.current_year_end
            THEN cr.COUNT ELSE 0 END) AS current_year_sum,
        SUM(CASE
            WHEN cr.REPORTDATE BETWEEN p.prior_year_start AND p.prior_year_end
            THEN cr.COUNT ELSE 0 END) AS prior_year_sum
    FROM
        crashes.crashes AS cr
        CROSS JOIN params p
    WHERE
        cr.SEVERITY = 'Fatal'
        AND cr.REPORTDATE >= p.prior_year_start -- More efficient date filtering
        AND cr.REPORTDATE <= p.current_year_end
)
SELECT
    'Fatal' AS severity,
    yc.current_year_sum,
    yc.prior_year_sum,
    ABS(yc.current_year_sum - yc.prior_year_sum) AS difference,
    CASE
        WHEN yc.prior_year_sum <> 0
        THEN ((yc.current_year_sum - yc.prior_year_sum)::numeric / yc.prior_year_sum)
        ELSE NULL
    END AS percentage_change,
    CASE
        WHEN (yc.current_year_sum - yc.prior_year_sum) > 0 THEN 'an increase of'
        WHEN (yc.current_year_sum - yc.prior_year_sum) < 0 THEN 'a decrease of'
        ELSE NULL
    END AS percentage_change_text,
    CASE
        WHEN (yc.current_year_sum - yc.prior_year_sum) > 0 THEN 'more'
        WHEN (yc.current_year_sum - yc.prior_year_sum) < 0 THEN 'fewer'
        ELSE 'no change'
    END AS difference_text,
    p.current_year,
    p.year_prior,
    CASE WHEN yc.current_year_sum = 1 THEN 'has' ELSE 'have' END AS has_have,
    CASE WHEN yc.current_year_sum = 1 THEN 'fatality' ELSE 'fatalities' END AS fatality
FROM
    yearly_counts yc
    CROSS JOIN params p;
```

```sql yoy_text_major_injury
WITH date_range AS (
    SELECT
        MAX(REPORTDATE)::DATE + INTERVAL '1 day' AS max_report_date
    FROM
        crashes.crashes
),
params AS (
    SELECT
        date_trunc('year', dr.max_report_date) AS current_year_start,
        dr.max_report_date AS current_year_end,
        date_trunc('year', dr.max_report_date - interval '1 year') AS prior_year_start,
        dr.max_report_date - interval '1 year' AS prior_year_end,
        extract(year FROM dr.max_report_date) AS current_year,
        extract(year FROM dr.max_report_date - interval '1 year') AS year_prior
    FROM
        date_range dr
),
yearly_counts AS (
    SELECT
        SUM(CASE
            WHEN cr.REPORTDATE BETWEEN p.current_year_start AND p.current_year_end
            THEN cr.COUNT ELSE 0 END) AS current_year_sum,
        SUM(CASE
            WHEN cr.REPORTDATE BETWEEN p.prior_year_start AND p.prior_year_end
            THEN cr.COUNT ELSE 0 END) AS prior_year_sum
    FROM
        crashes.crashes AS cr
        CROSS JOIN params p
    WHERE
        cr.SEVERITY = 'Major'
        AND cr.REPORTDATE >= p.prior_year_start -- More efficient date filtering
        AND cr.REPORTDATE <= p.current_year_end
)
SELECT
    'Major' AS severity,
    yc.current_year_sum,
    yc.prior_year_sum,
    ABS(yc.current_year_sum - yc.prior_year_sum) AS difference,
    CASE
        WHEN yc.prior_year_sum <> 0
        THEN ((yc.current_year_sum - yc.prior_year_sum)::numeric / yc.prior_year_sum)
        ELSE NULL
    END AS percentage_change,
    CASE
        WHEN (yc.current_year_sum - yc.prior_year_sum) > 0 THEN 'an increase of'
        WHEN (yc.current_year_sum - yc.prior_year_sum) < 0 THEN 'a decrease of'
        ELSE NULL
    END AS percentage_change_text,
    CASE
        WHEN (yc.current_year_sum - yc.prior_year_sum) > 0 THEN 'more'
        WHEN (yc.current_year_sum - yc.prior_year_sum) < 0 THEN 'fewer'
        ELSE 'no change'
    END AS difference_text,
    p.current_year,
    p.year_prior,
    CASE WHEN yc.current_year_sum = 1 THEN 'has' ELSE 'have' END AS has_have,
    CASE WHEN yc.current_year_sum = 1 THEN 'major injury' ELSE 'major injuries' END AS major_injury
FROM
    yearly_counts yc
    CROSS JOIN params p;
```

<!--
echartsOptions={{animation: false}}
-->

<DateRange
start="2017-01-01"
end={
    (last_record && last_record[0] && last_record[0].end_date)
    ? `${last_record[0].end_date}`
    : (() => {
        const twoDaysAgo = new Date(new Date().setDate(new Date().getDate() - 2));
        return new Intl.DateTimeFormat('en-CA', {
            timeZone: 'America/New_York'
        }).format(twoDaysAgo);
        })()
}
disableAutoDefault={true}
name="date_range"
presetRanges={['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'Last 6 Months', 'Last 12 Months', 'Month to Today', 'Last Month', 'Year to Today', 'Last Year']}
defaultValue="Year to Today"
description="By default, there is a two-day lag after the latest update"
/>

<Dropdown 
    data={age_range} 
    name=min_age
    value=age_int
    title="Min Age" 
    defaultValue={0}
/>

<Dropdown 
    data={age_range} 
    name="max_age"
    value=age_int
    title="Max Age"
    order="age_int desc"
    defaultValue={120}
    description='Age 120 serves as a placeholder for missing age values in the records. However, missing values will be automatically excluded from the query if the default 0-120 range is changed by the user. To get a count of missing age values, go to the "Age Distribution" page.'
/>

<Grid cols=2>

  <!-- Column 1: Fatalities (YTD vs prior YTD) -->
  <Group>
    <DataTable data={period_comp_fatal} totalRow sort="current_period_sum desc" wrapTitles rowShading title="Fatalities:">
      <Column id="MODE" title="Road User" description="*Fatal Only" wrap=true totalAgg="Total"/>
      <Column id="current_period_sum" title="{period_comp_fatal[0].current_period_range}"/>
      <Column id="prior_period_sum" title="{period_comp_fatal[0].prior_period_range}"/>
      <Column id="difference" contentType="delta" downIsGood title="Diff"/>
      <Column id="percentage_change" fmt="pct0" title="% Diff" totalAgg={period_comp_fatal[0].total_percentage_change} totalFmt="pct0"/>
    </DataTable>

    <div style="font-size: 14px;">
      <b>Percentage Breakdown:</b>
    </div>

    <BarChart 
      data={barchart_fatal}
      chartAreaHeight=80
      x=period_range
      y=period_sum
      xLabelWrap={true}
      swapXY=true
      yFmt=pct0
      series=MODE
      seriesColors={{"Pedestrian": '#00FFD4',"Other": '#06DFC8',"Bicyclist": '#0BBFBC',"Scooterist*": '#119FB0',"Motorcyclist*": '#167FA3',"Passenger": '#1C5F97',"Driver": '#271F7F',"Unknown": '#213F8B'}}
      labels={true}
      type=stacked100
      downloadableData=false
      downloadableImage=false
      leftPadding={10} 
    />
  </Group>

  <!-- Column 2: Major Injuries (YTD vs prior YTD) -->
  <Group>
      <DataTable data={period_comp_major} totalRow sort="current_period_sum desc" wrapTitles rowShading title="Major Injuries:">
      <Column id="MODE" title="Road User" description="*Fatal Only" wrap=true totalAgg="Total"/>
      <Column id="current_period_sum" title="{period_comp_major[0].current_period_range}"/>
      <Column id="prior_period_sum" title="{period_comp_major[0].prior_period_range}"/>
      <Column id="difference" contentType="delta" downIsGood title="Diff"/>
      <Column id="percentage_change" fmt="pct0" title="% Diff" totalAgg={period_comp_major[0].total_percentage_change} totalFmt="pct0"/>
    </DataTable>

    <div style="font-size: 14px;">
      <b>Percentage Breakdown:</b>
    </div>

    <BarChart 
      data={barchart_major}
      chartAreaHeight=80
      x=period_range
      y=period_sum
      xLabelWrap={true}
      swapXY=true
      yFmt=pct0
      series=MODE
      seriesColors={{"Pedestrian": '#00FFD4',"Other": '#06DFC8',"Bicyclist": '#0BBFBC',"Scooterist*": '#119FB0',"Motorcyclist*": '#167FA3',"Passenger": '#1C5F97',"Driver": '#271F7F',"Unknown": '#213F8B'}}
      labels={true}
      type=stacked100
      downloadableData=false
      downloadableImage=false
      leftPadding={10} 
    />
  </Group>

</Grid>

<Note>
    The latest crash record in the dataset is from <Value data={last_record} column="latest_record"/> and the data was last updated on <Value data={last_record} column="latest_update"/> hrs. This lag factors into prior period comparisons. The maximum comparison period is 5 years.
</Note>