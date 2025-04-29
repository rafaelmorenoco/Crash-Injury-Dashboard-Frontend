---
title: DC Vision Zero Traffic Fatalities and Injury Crashes
---

<Details title="About this dashboard">

    The Fatal and Injury Crashes Dashboard can be used by the public to know more about injuries or fatalities product of a crash in the District of Columbia (DC).
    
    Adjust the Mode, Severity and Date filters to refine the results.

</Details>

    - As of <Value data={last_record} column="latest_record"/> there <Value data={yoy_text_fatal} column="has_have"/> been <Value data={yoy_text_fatal} column="current_year_sum" agg=sum/> <Value data={yoy_text_fatal} column="fatality"/> for all modes in <Value data={yoy_text_fatal} column="current_year" fmt='####","'/>   <Value data={yoy_text_fatal} column="difference" agg=sum fmt='####' /> <Value data={yoy_text_fatal} column="difference_text"/> (<Delta data={yoy_text_fatal} column="percentage_change" fmt="+0%;-0%;0%" downIsGood=True neutralMin=-0.00 neutralMax=0.00/>) compared to the same period in <Value data={yoy_text_fatal} column="year_prior" fmt="####."/>
    - As of <Value data={last_record} column="latest_record"/> there <Value data={yoy_text_major_injury} column="has_have"/> been <Value data={yoy_text_major_injury} column="current_year_sum" agg=sum/> <Value data={yoy_text_major_injury} column="major_injury"/> for all modes in <Value data={yoy_text_major_injury} column="current_year" fmt='####","'/>   <Value data={yoy_text_major_injury} column="difference" agg=sum fmt='####' /> <Value data={yoy_text_major_injury} column="difference_text"/> (<Delta data={yoy_text_major_injury} column="percentage_change" fmt="+0%;-0%;0%" downIsGood=True neutralMin=-0.00 neutralMax=0.00/>) compared to the same period in <Value data={yoy_text_major_injury} column="year_prior" fmt="####."/>

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

```sql barchart_mode
    WITH report_date_range AS (
            SELECT
                CASE
                    WHEN '${inputs.date_range.end}' = CURRENT_DATE-2 THEN
                        (SELECT MAX(REPORTDATE) FROM crashes.crashes)
                    ELSE
                        '${inputs.date_range.end}'::DATE
                END AS end_date,
                '${inputs.date_range.start}'::DATE AS start_date
        ),
        combinations AS (
            SELECT DISTINCT
                MODE,
                SEVERITY
            FROM crashes.crashes
        ),
        counts AS (
            SELECT
                MODE,
                SEVERITY,
                SUM(COUNT) AS sum_count
            FROM crashes.crashes
            WHERE SEVERITY IN ${inputs.multi_severity.value}
            AND REPORTDATE BETWEEN (SELECT start_date FROM report_date_range) AND (SELECT end_date FROM report_date_range)
            GROUP BY MODE, SEVERITY
        )
        SELECT
            c.MODE,
            c.SEVERITY,
            COALESCE(cnt.sum_count, 0) AS sum_count
        FROM combinations c
        LEFT JOIN counts cnt
        ON c.MODE = cnt.MODE AND c.SEVERITY = cnt.SEVERITY;
```

```sql period_comp_mode
    WITH 
        report_date_range AS (
            SELECT
                CASE 
                    WHEN '${inputs.date_range.end}' = CURRENT_DATE-2 THEN 
                        (SELECT MAX(REPORTDATE) FROM crashes.crashes)
                    ELSE 
                        '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
                END AS end_date,
                '${inputs.date_range.start}'::DATE AS start_date
        ),
        date_info AS (
            SELECT
                start_date,
                end_date,
                CASE 
                    WHEN start_date = DATE_TRUNC('year', end_date)
                        AND end_date = (SELECT MAX(REPORTDATE) FROM crashes.crashes)
                    THEN
                        EXTRACT(YEAR FROM end_date)::VARCHAR || ' YTD'
                    ELSE
                        strftime(start_date, '%m/%d/%y') || '-' ||
                        strftime(end_date - INTERVAL '1 day', '%m/%d/%y')
                END AS date_range_label,
                (end_date - start_date) AS date_range_days
            FROM report_date_range
        ),
        offset_period AS (
            SELECT
                start_date,
                end_date,
                CASE 
                    WHEN end_date > start_date + INTERVAL '5 year' THEN (SELECT 1/0) -- Force error if more than 5 years
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
                SEVERITY IN ${inputs.multi_severity.value} 
                AND REPORTDATE >= (SELECT start_date FROM date_info)
                AND REPORTDATE <= (SELECT end_date FROM date_info)
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
                SEVERITY IN ${inputs.multi_severity.value} 
                AND REPORTDATE >= (
                    (SELECT start_date FROM date_info) - (SELECT interval_offset FROM offset_period)
                )
                AND REPORTDATE <= (
                    (SELECT end_date FROM date_info) - (SELECT interval_offset FROM offset_period)
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
                (SELECT end_date FROM date_info) - (SELECT interval_offset FROM offset_period) AS prior_end_date
        ),
        prior_date_label AS (
            SELECT
                CASE 
                    WHEN (SELECT start_date FROM date_info) = DATE_TRUNC('year', (SELECT end_date FROM date_info))
                        AND (SELECT end_date FROM date_info) = (SELECT MAX(REPORTDATE) FROM crashes.crashes)
                    THEN
                        EXTRACT(YEAR FROM prior_end_date)::VARCHAR || ' YTD'
                    ELSE
                        strftime(prior_start_date, '%m/%d/%y') || '-' ||
                        strftime(prior_end_date - INTERVAL '1 day', '%m/%d/%y')
                END AS prior_date_range_label
            FROM prior_date_info
        )
    SELECT 
        mas.MODE,
        COALESCE(cp.sum_count, 0) AS current_period_sum, 
        COALESCE(pp.sum_count, 0) AS prior_period_sum, 
        COALESCE(cp.sum_count, 0) - COALESCE(pp.sum_count, 0) AS difference,
        CASE 
            WHEN COALESCE(cp.sum_count, 0) = 0 THEN 
                NULL 
            WHEN COALESCE(pp.sum_count, 0) != 0 THEN 
                ((COALESCE(cp.sum_count, 0) - COALESCE(pp.sum_count, 0)) / COALESCE(pp.sum_count, 0)) 
            ELSE 
                NULL 
        END AS percentage_change,
        (SELECT date_range_label FROM date_info) AS current_period_range,
        (SELECT prior_date_range_label FROM prior_date_label) AS prior_period_range,
        (total_current_period - total_prior_period) / NULLIF(total_prior_period, 0) AS total_percentage_change
    FROM 
        modes_and_severities mas
    LEFT JOIN 
        current_period cp ON mas.MODE = cp.MODE
    LEFT JOIN 
        prior_period pp ON mas.MODE = pp.MODE,
        total_counts;
```

```sql period_comp_severity
    WITH 
        report_date_range AS (
            SELECT
                CASE 
                    WHEN '${inputs.date_range.end}' = CURRENT_DATE-2 THEN 
                        (SELECT MAX(REPORTDATE) FROM crashes.crashes)
                    ELSE 
                        '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
                END AS end_date,
                '${inputs.date_range.start}'::DATE AS start_date
        ),
        date_info AS (
            SELECT
                start_date,
                end_date,
                CASE 
                    WHEN start_date = DATE_TRUNC('year', end_date)
                        AND end_date = (SELECT MAX(REPORTDATE) FROM crashes.crashes)
                    THEN
                        EXTRACT(YEAR FROM end_date)::VARCHAR || ' YTD'
                    ELSE
                        strftime(start_date, '%m/%d/%y') || '-' || strftime(end_date - INTERVAL '1 day', '%m/%d/%y')
                END AS date_range_label,
                (end_date - start_date) AS date_range_days
            FROM report_date_range
        ),
        offset_period AS (
            SELECT
                start_date,
                end_date,
                CASE 
                    WHEN end_date > start_date + INTERVAL '5 year' THEN (SELECT 1/0) -- Force error if more than 5 years
                    WHEN end_date > start_date + INTERVAL '4 year' THEN INTERVAL '5 year'
                    WHEN end_date > start_date + INTERVAL '3 year' THEN INTERVAL '4 year'
                    WHEN end_date > start_date + INTERVAL '2 year' THEN INTERVAL '3 year'
                    WHEN end_date > start_date + INTERVAL '1 year' THEN INTERVAL '2 year'
                    ELSE INTERVAL '1 year'
                END AS interval_offset
            FROM date_info
        ),
        severities AS (
            SELECT DISTINCT 
                SEVERITY
            FROM 
                crashes.crashes
            WHERE
                SEVERITY IN ${inputs.multi_severity.value}     
        ), 
        current_period AS (
            SELECT 
                SEVERITY,
                SUM(COUNT) AS sum_count
            FROM 
                crashes.crashes 
            WHERE 
                SEVERITY IN ${inputs.multi_severity.value} 
                AND REPORTDATE >= (SELECT start_date FROM date_info)
                AND REPORTDATE <= (SELECT end_date FROM date_info)
            GROUP BY 
                SEVERITY
        ), 
        prior_period AS (
            SELECT 
                SEVERITY,
                SUM(COUNT) AS sum_count
            FROM 
                crashes.crashes 
            WHERE 
                SEVERITY IN ${inputs.multi_severity.value} 
                AND REPORTDATE >= (
                    (SELECT start_date FROM offset_period) - (SELECT interval_offset FROM offset_period)
                )
                AND REPORTDATE <= (
                    (SELECT end_date FROM offset_period) - (SELECT interval_offset FROM offset_period)
                )
            GROUP BY 
                SEVERITY
        ), 
        total_counts AS (
            SELECT 
                SUM(cp.sum_count) AS total_current_period,
                SUM(pp.sum_count) AS total_prior_period
            FROM 
                current_period cp
            FULL JOIN 
                prior_period pp 
            ON cp.SEVERITY = pp.SEVERITY
        ),
        prior_date_info AS (
            SELECT
                (SELECT start_date FROM date_info) - (SELECT interval_offset FROM offset_period) AS prior_start_date,
                (SELECT end_date FROM date_info)   - (SELECT interval_offset FROM offset_period) AS prior_end_date
        ),
        prior_date_label AS (
            SELECT
                CASE 
                    WHEN (SELECT start_date FROM date_info) = DATE_TRUNC('year', (SELECT end_date FROM date_info))
                        AND (SELECT end_date FROM date_info) = (SELECT MAX(REPORTDATE) FROM crashes.crashes)
                    THEN
                        EXTRACT(YEAR FROM prior_end_date)::VARCHAR || ' YTD'
                    ELSE
                        strftime(prior_start_date, '%m/%d/%y') || '-' || strftime(prior_end_date - INTERVAL '1 day', '%m/%d/%y')
                END AS prior_date_range_label
            FROM prior_date_info
        )
    SELECT 
        s.SEVERITY,
        COALESCE(cp.sum_count, 0) AS current_period_sum, 
        COALESCE(pp.sum_count, 0) AS prior_period_sum, 
        COALESCE(cp.sum_count, 0) - COALESCE(pp.sum_count, 0) AS difference,
        CASE 
            WHEN COALESCE(cp.sum_count, 0) = 0 THEN NULL
            WHEN COALESCE(pp.sum_count, 0) <> 0 THEN ((COALESCE(cp.sum_count, 0) - COALESCE(pp.sum_count, 0)) / COALESCE(pp.sum_count, 0))
            ELSE NULL
        END AS percentage_change,
        (SELECT date_range_label FROM date_info) AS current_period_range,
        (SELECT prior_date_range_label FROM prior_date_label) AS prior_period_range,
        (total_current_period - total_prior_period) / NULLIF(total_prior_period, 0) AS total_percentage_change
    FROM 
        severities s
    LEFT JOIN 
        current_period cp ON s.SEVERITY = cp.SEVERITY
    LEFT JOIN 
        prior_period pp ON s.SEVERITY = pp.SEVERITY,
        total_counts;
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

```sql severity_selection
    SELECT
        STRING_AGG(DISTINCT SEVERITY, ', ' ORDER BY SEVERITY ASC) AS SEVERITY_SELECTION
    FROM
        crashes.crashes
    WHERE
        SEVERITY IN ${inputs.multi_severity.value}; 
```

<!--
echartsOptions={{animation: false}}
-->

<DateRange
    start='2018-01-01'
    end={new Date(new Date().setDate(new Date().getDate() - 2))
    .toISOString()
    .split('T')[0]}
    title="Select Time Period"
    name=date_range
    presetRanges={['Month to Today','Last Month','Year to Today','Last Year']}
    defaultValue={'Year to Today'}
    description="By default, there is a two-day lag after the latest update"
/>

<Dropdown
    data={unique_severity} 
    name=multi_severity
    value=SEVERITY
    title="Select Severity"
    multiple=true
    defaultValue={['Fatal', 'Major']}
/>

<Alert status="info">
The slection for <b>Severity</b> is: <b><Value data={severity_selection} column="SEVERITY_SELECTION"/></b>.
</Alert>

### Injuries by Mode and Severity

<Grid cols=2>
    <Group>
        <BarChart 
            title="Selected Period"
            chartAreaHeight=300
            subtitle="Mode"
            data={barchart_mode}
            x=MODE
            y=sum_count
            series=SEVERITY
            seriesColors={{"Major": '#ff9412',"Minor": '#ffdf00',"Fatal": '#ff5a53'}}
            swapXY=true
            labels=true
            leftPadding=10
            rightPadding=30
        />
        <Note>
            *Fatal only.
        </Note>
    </Group>
        <Group>
        <DataTable data={period_comp_mode} totalRow=true sort="current_period_sum desc" wrapTitles=true rowShading=true title="Selected Period Comparison">
            <Column id=MODE wrap=true totalAgg="Total"/>
            <Column id=current_period_sum title={`${period_comp_mode[0].current_period_range}`} />
            <Column id=prior_period_sum title={`${period_comp_mode[0].prior_period_range}`} />
            <Column id=difference contentType=delta downIsGood=True title="Diff"/>
            <Column id=percentage_change fmt=pct title="% Diff" totalAgg={period_comp_mode[0].total_percentage_change} totalFmt=pct/> 
        </DataTable>
        <DataTable data={period_comp_severity} totalRow=true sort="current_period_sum desc" wrapTitles=true rowShading=true>
            <Column id=SEVERITY wrap=true totalAgg="Total"/>
            <Column id=current_period_sum title={`${period_comp_severity[0].current_period_range}`} />
            <Column id=prior_period_sum title={`${period_comp_severity[0].prior_period_range}`}  />
            <Column id=difference contentType=delta downIsGood=True title="Diff"/>
            <Column id=percentage_change fmt=pct title="% Diff" totalAgg={period_comp_severity[0].total_percentage_change} totalFmt=pct /> 
        </DataTable>
        <Note>
            *Fatal only.
        </Note>
    </Group>
</Grid>

<Note>
    The latest crash record in the dataset is from <Value data={last_record} column="latest_record"/> and the data was last updated on <Value data={last_record} column="latest_update"/> hrs. This lag factors into prior period comparisons. The maximum comparison period is 5 years.
</Note>

<Details title="About the data">

The data come from the tables Crashes in DC and Crash Details from DC's Open Data portal (see links below), as well as internal tracking of traffic fatalities by the District Department of Transportation (DDOT) and the Metropolitan Police Department (MPD). 
    
### The data is filtered to:
        - Only keep records of crashes that occured on or after 1/1/2017
        - Only keep records of crashes that involved a fatality, a major injury, or minor injury. See section "Injury Crashes" below. 

All counts on this page are for persons injured, NOT the number of crashes. For example, one crash may involve injuries to three persons; in that case, all three persons will be counted in all the charts and indicators on this dashboard. 

Injury Crashes are defined based on information collected at the scene of the crash. See below for examples of the different types of injury categories. 

### Injury Category:
        - Major Injury:	Unconsciousness; Apparent Broken Bones; Concussion; Gunshot (non-fatal); Severe Laceration; Other Major Injury. 
        - Minor Injury:	Abrasions; Minor Cuts; Discomfort; Bleeding; Swelling; Pain; Apparent Minor Injury; Burns-minor; Smoke Inhalation; Bruises

While the injury crashes shown on this map include any type of injury, summaries of injuries submitted for federal reports only include those that fall under the Model Minimum Uniform Crash Criteria https://www.nhtsa.gov/mmucc-1, which do not include "discomfort" and "pain". Note: Data definitions of injury categories may differ due to source (e.g., federal rules) and may change over time, which may cause numbers to vary among data sources. 

All data comes from MPD. 

    - Crashes in DC (Open Data): https://opendata.dc.gov/datasets/crashes-in-dc
    - Crash Details (Open Data): https://opendata.dc.gov/datasets/crash-details-table

</Details>