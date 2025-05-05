---
title: Multiyear Trend
sidebar_position: 7
---

<Details title="About this dashboard">

    The Fatal and Injury Crashes Dashboard can be used by the public to know more about injuries or fatalities product of a crash in the District of Columbia (DC).
    
    Adjust the Mode, Severity and Date filters to refine the results.

</Details>

<!--
    - As of <Value data={last_record} column="latest_record"/> there <Value data={yoy_text_fatal} column="has_have"/> been <Value data={yoy_text_fatal} column="current_year_sum" agg=sum/> <Value data={yoy_text_fatal} column="fatality"/> for all modes in <Value data={yoy_text_fatal} column="current_year" fmt='####","'/>   <Value data={yoy_text_fatal} column="difference" agg=sum fmt='####' /> <Value data={yoy_text_fatal} column="difference_text"/> (<Delta data={yoy_text_fatal} column="percentage_change" fmt="+0%;-0%;0%" downIsGood=True neutralMin=-0.00 neutralMax=0.00/>) compared to the same period in <Value data={yoy_text_fatal} column="year_prior" fmt="####."/>
    - As of <Value data={last_record} column="latest_record"/> there <Value data={yoy_text_major_injury} column="has_have"/> been <Value data={yoy_text_major_injury} column="current_year_sum" agg=sum/> <Value data={yoy_text_major_injury} column="major_injury"/> for all modes in <Value data={yoy_text_major_injury} column="current_year" fmt='####","'/>   <Value data={yoy_text_major_injury} column="difference" agg=sum fmt='####' /> <Value data={yoy_text_major_injury} column="difference_text"/> (<Delta data={yoy_text_major_injury} column="percentage_change" fmt="+0%;-0%;0%" downIsGood=True neutralMin=-0.00 neutralMax=0.00/>) compared to the same period in <Value data={yoy_text_major_injury} column="year_prior" fmt="####."/>
-->

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

```sql unique_year
SELECT DISTINCT strftime('%Y', REPORTDATE) AS year_string
FROM crashes.crashes
WHERE strftime('%Y', REPORTDATE) BETWEEN '2018' 
    AND (SELECT strftime('%Y', MAX(REPORTDATE)) FROM crashes.crashes)
ORDER BY year_string DESC;
```

```sql unique_cy
SELECT DISTINCT CAST(DATE_PART('year', REPORTDATE) AS VARCHAR) AS year_string
FROM crashes.crashes
WHERE DATE_PART('year', REPORTDATE) BETWEEN 2018
    AND (SELECT DATE_PART('year', MAX(REPORTDATE)) FROM crashes.crashes)
    AND DATE_PART('year', REPORTDATE) <> DATE_PART('year', CURRENT_DATE)
ORDER BY year_string DESC;

```

```sql unique_hin
select 
    GIS_ID,
    ROUTENAME
from hin.hin
group by all
```

```sql last_record
    SELECT
        LPAD(CAST(DATE_PART('month', LAST_RECORD) AS VARCHAR), 2, '0') || '/' ||
        LPAD(CAST(DATE_PART('day', LAST_RECORD) AS VARCHAR), 2, '0') || '/' ||
        RIGHT(CAST(DATE_PART('year', LAST_RECORD) AS VARCHAR), 2) || ',' AS latest_record,
        LPAD(CAST(DATE_PART('month', LAST_UPDATE) AS VARCHAR), 2, '0') || '/' ||
        LPAD(CAST(DATE_PART('day', LAST_UPDATE) AS VARCHAR), 2, '0') || '/' ||
        RIGHT(CAST(DATE_PART('year', LAST_UPDATE) AS VARCHAR), 2) || ' at ' ||
        LPAD(CAST(DATE_PART('hour', LAST_UPDATE) AS VARCHAR), 2, '0') || ':' ||
        LPAD(CAST(DATE_PART('minute', LAST_UPDATE) AS VARCHAR), 2, '0') AS latest_update
    FROM crashes.crashes
    ORDER BY LAST_RECORD DESC
    LIMIT 1;
```

```sql linechart_month
WITH 
    report_date_range AS (
        SELECT
            CASE 
                WHEN '${inputs.date_range_cumulative.end}'::DATE >= 
                     (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes) THEN 
                    (SELECT MAX(REPORTDATE) FROM crashes.crashes)
                ELSE 
                    '${inputs.date_range_cumulative.end}'::DATE + INTERVAL '1 day'
            END AS end_date,
            '${inputs.date_range_cumulative.start}'::DATE AS start_date
    ),
    months AS (
        SELECT 1 AS month, 'Jan' AS month_name UNION ALL
        SELECT 2, 'Feb' UNION ALL
        SELECT 3, 'Mar' UNION ALL
        SELECT 4, 'Apr' UNION ALL
        SELECT 5, 'May' UNION ALL
        SELECT 6, 'Jun' UNION ALL
        SELECT 7, 'Jul' UNION ALL
        SELECT 8, 'Aug' UNION ALL
        SELECT 9, 'Sep' UNION ALL
        SELECT 10, 'Oct' UNION ALL
        SELECT 11, 'Nov' UNION ALL
        SELECT 12, 'Dec'
    ),
    monthly_counts AS (
        SELECT 
            EXTRACT(YEAR FROM REPORTDATE) AS year,
            EXTRACT(MONTH FROM REPORTDATE) AS month,
            SUM("COUNT") AS monthly_total
        FROM crashes.crashes
        WHERE 
            MODE IN ${inputs.multi_mode_dd.value}
            AND SEVERITY IN ${inputs.multi_severity.value}
            AND REPORTDATE BETWEEN (SELECT start_date FROM report_date_range)
                              AND (SELECT end_date FROM report_date_range)
        GROUP BY 
            EXTRACT(YEAR FROM REPORTDATE), 
            EXTRACT(MONTH FROM REPORTDATE)
    ),
    -- get the last year in our data (often the current year)
    max_year_cte AS (
        SELECT MAX(year) AS max_year
        FROM monthly_counts
    ),
    -- get the latest month with data for the max_year
    max_month_cte AS (
        SELECT MAX(month) AS max_data_month
        FROM monthly_counts
        WHERE year = (SELECT max_year FROM max_year_cte)
    ),
    -- get the current month from the system
    current_month_cte AS (
        SELECT EXTRACT(MONTH FROM CURRENT_DATE) AS current_month
    )
SELECT 
    y.year,
    m.month,
    m.month_name,
    COALESCE(mc.monthly_total, 0) AS monthly_total,
    SUM(COALESCE(mc.monthly_total, 0)) OVER (PARTITION BY y.year ORDER BY m.month ASC) AS cumulative_total
FROM
    (SELECT DISTINCT year FROM monthly_counts) y
CROSS JOIN months m
LEFT JOIN monthly_counts mc 
    ON y.year = mc.year AND m.month = mc.month
WHERE
    -- for years other than the max_year, show all months
    y.year <> (SELECT max_year FROM max_year_cte)
    OR
    -- for the max_year, show months up to the effective month.
    -- effective_max_month is the greater of the last data month and the current month.
    m.month <= (
        SELECT CASE 
                 WHEN (SELECT current_month FROM current_month_cte) > max_data_month 
                      THEN (SELECT current_month FROM current_month_cte)
                 ELSE max_data_month
               END
        FROM max_month_cte
    )
ORDER BY y.year DESC, m.month;
```

```sql yoy_text_fatal
    WITH date_range AS (
        SELECT
            MAX(REPORTDATE) AS max_report_date
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
            MAX(REPORTDATE) AS max_report_date
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

```sql mode_severity_selection
    SELECT
        STRING_AGG(DISTINCT MODE, ', ' ORDER BY MODE ASC) AS MODE_SELECTION,
        STRING_AGG(DISTINCT SEVERITY, ', ' ORDER BY SEVERITY ASC) AS SEVERITY_SELECTION
    FROM
        crashes.crashes
    WHERE
        MODE IN ${inputs.multi_mode_dd.value}
        AND SEVERITY IN ${inputs.multi_severity.value};
```

```sql ytd_table
WITH 
  -- Determine the effective current date range based on input and the maximum available REPORTDATE.
  report_date_range AS (
    SELECT
      CASE 
          WHEN '${inputs.date_range.end}'::DATE >= 
               (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes) 
            THEN (SELECT MAX(REPORTDATE) FROM crashes.crashes)
          ELSE '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
      END AS current_end_date,
      '${inputs.date_range.start}'::DATE AS current_start_date
  ),
  -- Extract month/day details, current year & build a date_range_label following your criteria.
  date_info AS (
    SELECT 
      current_start_date AS start_date,
      current_end_date AS end_date,
      CASE 
          WHEN current_start_date = DATE_TRUNC('year', current_end_date)
               AND '${inputs.date_range.end}'::DATE = 
                 (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes)
            THEN 'to Date'
          WHEN '${inputs.date_range.end}'::DATE > 
               (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes)
            THEN strftime(current_start_date, '%m/%d') 
                 || '-' || strftime(current_end_date, '%m/%d')
          ELSE 
            strftime(current_start_date, '%m/%d') 
                 || '-' || strftime(current_end_date - INTERVAL '1 day', '%m/%d')
      END AS date_range_label,
      (current_end_date - current_start_date) AS date_range_days,
      strftime(current_start_date, '%m-%d') AS month_day_start,
      strftime(current_end_date, '%m-%d') AS month_day_end,
      EXTRACT(YEAR FROM current_end_date) AS current_year
    FROM report_date_range
  ),
  -- Build the allowed list of years from the crashes table (as strings) within a lower bound and the max date,
  -- then filter by the multi_year input.
  years AS (
    SELECT CAST(year_string AS INTEGER) AS yr
    FROM (
      SELECT DISTINCT strftime('%Y', REPORTDATE) AS year_string
      FROM crashes.crashes
      WHERE strftime('%Y', REPORTDATE) BETWEEN '2018' 
            AND (SELECT strftime('%Y', MAX(REPORTDATE)) FROM crashes.crashes)
    ) unique_years
    WHERE year_string IN ${inputs.multi_year.value}
    ORDER BY year_string DESC
  ),
  -- For each year in the allowed list, compute the incident count for the date range derived from date_info.
  yearly_counts AS (
    SELECT 
      y.yr,
      (
        SELECT SUM("COUNT")
        FROM crashes.crashes, date_info d
        WHERE REPORTDATE >= CAST(y.yr || '-' || d.month_day_start AS DATE)
          AND REPORTDATE < CAST(y.yr || '-' || d.month_day_end AS DATE) + INTERVAL '1 day'
          AND crashes.SEVERITY IN ${inputs.multi_severity.value}
          AND crashes.MODE IN ${inputs.multi_mode_dd.value}
      ) AS year_count
    FROM years y
  ),
  -- Grab the current year count using the effective current year's period.
  current_year_count AS (
    SELECT year_count AS current_count
    FROM yearly_counts, date_info
    WHERE yr = current_year
  )
  
-- Return the results, including an added column with the formatted date range.
SELECT 
  yc.yr AS Year,
  COALESCE(yc.year_count, 0) AS Count,
  COALESCE(cyc.current_count, 0) - COALESCE(yc.year_count, 0) AS Diff_from_current,
  CASE 
    WHEN COALESCE(yc.year_count, 0) = 0 THEN NULL
    ELSE (COALESCE(cyc.current_count, 0) - COALESCE(yc.year_count, 0)) * 1.0 / yc.year_count
  END AS Percent_Diff_from_current,
  (SELECT date_range_label FROM date_info) AS Date_Range
FROM yearly_counts yc
CROSS JOIN current_year_count cyc
ORDER BY yc.yr DESC;
```

```sql cy_table
WITH 
  -- Establish the effective boundaries from the cy input.
  report_date_range_cy AS (
    SELECT 
      '${inputs.date_range_cy.start}'::DATE AS cy_start_date,
      CASE 
        WHEN '${inputs.date_range_cy.end}'::DATE >= (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes)
          THEN (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes)
        ELSE '${inputs.date_range_cy.end}'::DATE
      END AS cy_end_date
  ),
  -- Prepare the month/day parts from the cy range.
  date_info_cy AS (
    SELECT 
      cy_start_date,
      cy_end_date,
      strftime(cy_start_date, '%m-%d') AS start_md,
      strftime(cy_end_date, '%m-%d') AS end_md,
      EXTRACT(YEAR FROM cy_end_date) AS cy_year
    FROM report_date_range_cy
  ),
  -- Define the allowed years (ensure the input list uses numbers that match your data).
  allowed_years AS (
    SELECT DISTINCT CAST(strftime('%Y', REPORTDATE) AS INTEGER) AS yr
    FROM crashes.crashes
    WHERE CAST(strftime('%Y', REPORTDATE) AS INTEGER)
          BETWEEN 2018 AND (SELECT CAST(strftime('%Y', MAX(REPORTDATE)) AS INTEGER) FROM crashes.crashes)
      AND CAST(strftime('%Y', REPORTDATE) AS INTEGER) IN ${inputs.multi_cy.value}
  ),
  -- For each allowed year compute the sum of counts using the cy date boundaries.
  yearly_counts AS (
    SELECT 
      ay.yr,
      (
        SELECT SUM("COUNT")
        FROM crashes.crashes c, date_info_cy d
        WHERE c.REPORTDATE >= CAST(ay.yr || '-' || d.start_md AS DATE)
          AND c.REPORTDATE < CAST(ay.yr || '-' || d.end_md AS DATE) + INTERVAL '1 day'
          AND c.SEVERITY IN ${inputs.multi_severity.value}
          AND c.MODE IN ${inputs.multi_mode_dd.value}
      ) AS year_count
    FROM allowed_years ay
  )
  
SELECT 
  yc.yr AS Year,
  COALESCE(yc.year_count, 0) AS Count,
  CASE 
    WHEN LAG(COALESCE(yc.year_count, 0)) OVER (ORDER BY yc.yr DESC) IS NULL 
      THEN 0
    ELSE LAG(COALESCE(yc.year_count, 0)) OVER (ORDER BY yc.yr DESC) - COALESCE(yc.year_count, 0)
  END AS Diff_from_previous,
  CASE 
    WHEN LAG(COALESCE(yc.year_count, 0)) OVER (ORDER BY yc.yr DESC) IS NULL 
         OR LAG(COALESCE(yc.year_count, 0)) OVER (ORDER BY yc.yr DESC) = 0
      THEN 0
    ELSE (LAG(COALESCE(yc.year_count, 0)) OVER (ORDER BY yc.yr DESC) - COALESCE(yc.year_count, 0)) * 1.0 
         / LAG(COALESCE(yc.year_count, 0)) OVER (ORDER BY yc.yr DESC)
  END AS Percent_Diff_from_previous,
  (SELECT strftime(cy_start_date, '%m/%d') || '-' || strftime(cy_end_date, '%m/%d') 
   FROM report_date_range_cy) AS Date_Range
FROM yearly_counts yc
ORDER BY yc.yr DESC;
```

<Dropdown
    data={unique_severity} 
    name=multi_severity
    value=SEVERITY
    title="Select Severity"
    multiple=true
    defaultValue={["Major","Fatal"]}
/>

<Dropdown
    data={unique_mode} 
    name=multi_mode_dd
    value=MODE
    title="Select Mode"
    multiple=true
    selectAllByDefault=true
    description="*Only fatal"
/>

<Alert status="info">
The slection for <b>Severity</b> is: <b><Value data={mode_severity_selection} column="SEVERITY_SELECTION"/></b>. The slection for <b>Mode</b> is: <b><Value data={mode_severity_selection} column="MODE_SELECTION"/></b> <Info description="*Fatal only." color="primary" />
</Alert>

<Grid cols=2>
    <Group>
        <DateRange
        start='2018-01-01'
        end={
            (() => {
            const twoDaysAgo = new Date(new Date().setDate(new Date().getDate() - 2));
            return new Intl.DateTimeFormat('en-CA', {
                timeZone: 'America/New_York'
            }).format(twoDaysAgo);
            })()
        }
        title="Select Time Period"
        name="date_range_cumulative"
        presetRanges={['All Time']}
        defaultValue='All Time'
        description="By default, there is a two-day lag after the latest update"
        />
        <LineChart 
            title="Yearly Cumulative"
            chartAreaHeight={450}
            subtitle="Injuries"
            data={linechart_month}
            x="month"
            y="cumulative_total"
            series="year"
            labels={false}
            echartsOptions={{
                legend: {
                    data: ["2040","2039","2038","2037","2036","2035","2034","2033","2032","2031","2030","2030","2029","2028","2027","2026","2025","2024","2023","2022","2021","2020","2019","2018","2017","2016","2015"],
                },
                xAxis: {
                    type: 'category',
                    axisLabel: {
                        rotate: 90,
                        formatter: function(value) {
                            const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                            return months[value - 1] || value;
                        }
                    }
                },
                tooltip: {
                    trigger: 'axis',
                    formatter: function(params) {
                        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                        const monthNumber = params[0].axisValue;
                        const monthLabel = months[monthNumber - 1] || monthNumber;
            
                        let tooltipContent = `<strong>${monthLabel}</strong><br/>`;
                        params.forEach(item => {
                            const value = Array.isArray(item.value) ? item.value[1] : item.value;
                            tooltipContent += `${item.marker} <strong>${item.seriesName}</strong>: ${value}<br/>`;
                        });
                        return tooltipContent;
                    }
                }
            }}
        />
    </Group>
    <Group>
        <DateRange
        start={
            (() => {
            const beginningOfYear = new Date(new Date().getFullYear(), 0, 1);
            return new Intl.DateTimeFormat('en-CA', {
                timeZone: 'America/New_York'
            }).format(beginningOfYear);
            })()
        }
        end={
            (() => {
            const twoDaysAgo = new Date(new Date().setDate(new Date().getDate() - 2));
            return new Intl.DateTimeFormat('en-CA', {
                timeZone: 'America/New_York'
            }).format(twoDaysAgo);
            })()
        }
        title="Select Time Period"
        name="date_range"
        presetRanges={['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'Last 6 Months', 'Last 12 Months', 'Month to Today', 'Last Month', 'Year to Today']}
        defaultValue="Year to Today"
        description="By default, there is a two-day lag after the latest update"
        />
        <Dropdown
            data={unique_year} 
            name=multi_year
            value=year_string
            title="Select Year"
            multiple=true
            selectAllByDefault=true
        />
        <DataTable data={ytd_table} wrapTitles=true rowShading=true title="{ytd_table[0].Year} {ytd_table[0].Date_Range} vs Prior Years {ytd_table[0].Date_Range}">
            <Column id=Year wrap=true/>
            <Column id=Count title="Injured"/>
            <Column id=Diff_from_current contentType=delta downIsGood=True title="Diff From {ytd_table[0].Year}"/>
            <Column id=Percent_Diff_from_current fmt='pct0' title="% Diff From {ytd_table[0].Year}"/> 
        </DataTable>
            <DateRange
                start={
                    (() => {
                    // Get the previous year
                    const priorYear = new Date().getFullYear() - 1;
                    // January is month 0
                    const priorYearStart = new Date(priorYear, 0, 1);
                    return new Intl.DateTimeFormat('en-CA', {
                        timeZone: 'America/New_York'
                    }).format(priorYearStart);
                    })()
                }
                end={
                    (() => {
                    // Get the previous year
                    const priorYear = new Date().getFullYear() - 1;
                    // December is month 11
                    const priorYearEnd = new Date(priorYear, 11, 31);
                    return new Intl.DateTimeFormat('en-CA', {
                        timeZone: 'America/New_York'
                    }).format(priorYearEnd);
                    })()
                }
                title="Select Time Period"
                name="date_range_cy"
                presetRanges={['All Time']}
                defaultValue="All Time"
                description="Date range set to the entirety of the previous year"
            />
            <Dropdown
                data={unique_cy} 
                name=multi_cy
                value=year_string
                title="Select Year"
                multiple=true
                selectAllByDefault=true
            />
            <DataTable data={cy_table} wrapTitles=true rowShading=true title="Comparison of Prior Years from {cy_table[0].Date_Range}">
                <Column id=Year wrap=true/>
                <Column id=Count title="Injured"/>
                <Column id=Diff_from_previous contentType=delta downIsGood=True title="Diff From Prior Year"/>
                <Column id=Percent_Diff_from_previous fmt='pct0' title="% Diff From Prior Year"/> 
        </DataTable>
    </Group>
</Grid>

<Note>
    The latest crash record in the dataset is from <Value data={last_record} column="latest_record"/> and the data was last updated on <Value data={last_record} column="latest_update"/> hrs. This lag factors into prior period comparisons.
</Note>