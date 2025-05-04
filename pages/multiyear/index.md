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
                    WHEN '${inputs.date_range.end}'::DATE >= (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes) THEN 
                        (SELECT MAX(REPORTDATE) FROM crashes.crashes)
                    ELSE 
                        '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
                END AS end_date,
                '${inputs.date_range.start}'::DATE AS start_date
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
    max_year_cte AS (
        SELECT MAX(year) AS max_year
        FROM monthly_counts
    ),
    max_month_cte AS (
        SELECT MAX(month) AS max_month
        FROM monthly_counts
        WHERE year = (SELECT max_year FROM max_year_cte)
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
        y.year <> (SELECT max_year FROM max_year_cte)
        OR m.month <= (SELECT max_month FROM max_month_cte)
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

<!--sql multiyear_table
WITH 
    report_date_range AS (
        SELECT
            CASE 
                WHEN '${inputs.date_range.end}' = CURRENT_DATE - 2 THEN 
                    (SELECT MAX(REPORTDATE) FROM crashes.crashes)
                ELSE 
                    '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
            END AS end_date,
            '${inputs.date_range.start}'::DATE AS start_date
    ),
    -- Use UNNEST on generate_series to produce a table of years.
    years AS (
        SELECT t.value AS year
        FROM report_date_range r,
             UNNEST(
                generate_series(
                    CAST(strftime(r.start_date, '%Y') AS INTEGER),
                    CAST(strftime(r.end_date, '%Y') AS INTEGER)
                )
             ) AS t(value)
    ),
    -- For each year, determine its effective start and end dates.
    year_range AS (
        SELECT
            y.year,
            CASE 
                WHEN y.year = CAST(strftime(r.start_date, '%Y') AS INTEGER)
                THEN r.start_date
                ELSE CAST(CAST(y.year AS VARCHAR) || '-01-01' AS DATE)
            END AS effective_start,
            CASE 
                WHEN y.year = CAST(strftime(r.end_date, '%Y') AS INTEGER)
                THEN r.end_date - INTERVAL '1 day'
                ELSE CAST(CAST(y.year AS VARCHAR) || '-12-31' AS DATE)
            END AS effective_end
        FROM years y
        CROSS JOIN report_date_range r
    ),
    -- Aggregate the crash counts by year using these effective boundaries.
    crashes_by_year AS (
        SELECT
            yr.year,
            SUM(c.COUNT) AS total_count
        FROM year_range AS yr
        JOIN crashes.crashes AS c 
          ON c.REPORTDATE >= yr.effective_start
         AND c.REPORTDATE <= yr.effective_end
        GROUP BY yr.year
    )
SELECT
    yr.year,
    strftime(yr.effective_start, '%m/%d') || '-' || strftime(yr.effective_end, '%m/%d') AS date_range,
    COALESCE(cby.total_count, 0) AS count,
    COALESCE(cby.total_count, 0) - COALESCE(LAG(cby.total_count) OVER (ORDER BY yr.year), 0)
         AS diff_from_year_prior,
    CASE 
        WHEN COALESCE(LAG(cby.total_count) OVER (ORDER BY yr.year), 0) = 0 THEN NULL
        ELSE ((COALESCE(cby.total_count, 0) - LAG(cby.total_count) OVER (ORDER BY yr.year)) * 100.0)
             / LAG(cby.total_count) OVER (ORDER BY yr.year)
    END AS percentage_diff_from_year_prior
FROM year_range AS yr
LEFT JOIN crashes_by_year AS cby 
  ON yr.year = cby.year
ORDER BY yr.year;
-->

<DateRange
  start="2018-01-01"
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
  presetRanges={['Year to Today', 'Last Year', 'All Time']}
  defaultValue="All Time"
  description="By default, there is a two-day lag after the latest update"
/>

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

### Injuries by Mode and Severity

<Grid cols=2>
    <Group>
        <LineChart 
            title="Yearly Cumulative"
            chartAreaHeight={350}
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
        <!--
        <DataTable data={period_comp_mode} totalRow=true sort="current_period_sum desc" wrapTitles=true rowShading=true title="Selected Period Comparison">
            <Column id=MODE wrap=true totalAgg="Total"/>
            <Column id=current_period_sum title={`${period_comp_mode[0].current_period_range}`} />
            <Column id=prior_period_sum title={`${period_comp_mode[0].prior_period_range}`} />
            <Column id=difference contentType=delta downIsGood=True title="Diff"/>
            <Column id=percentage_change fmt='pct0' title="% Diff" totalAgg={period_comp_mode[0].total_percentage_change} totalFmt='pct0'/> 
        </DataTable>
        <DataTable data={period_comp_severity} totalRow=true sort="current_period_sum desc" wrapTitles=true rowShading=true>
            <Column id=SEVERITY wrap=true totalAgg="Total"/>
            <Column id=current_period_sum title={`${period_comp_severity[0].current_period_range}`} />
            <Column id=prior_period_sum title={`${period_comp_severity[0].prior_period_range}`}  />
            <Column id=difference contentType=delta downIsGood=True title="Diff"/>
            <Column id=percentage_change fmt='pct0' title="% Diff" totalAgg={period_comp_severity[0].total_percentage_change} totalFmt='pct0' /> 
        </DataTable>
        <Note>
            *Fatal only.
        </Note>
    -->
    </Group>
</Grid>

<Note>
    The latest crash record in the dataset is from <Value data={last_record} column="latest_record"/> and the data was last updated on <Value data={last_record} column="latest_update"/> hrs. This lag factors into prior period comparisons.
</Note>