---
title: DC Vision Zero Traffic Fatalities and Injury Crashes
---

    - As of <Value data={last_record} column="latest_record"/> there <Value data={yoy_text_fatal} column="has_have"/> been <Value data={yoy_text_fatal} column="current_year_sum" agg=sum/> <Value data={yoy_text_fatal} column="fatality"/> for all modes in <Value data={yoy_text_fatal} column="current_year" fmt='####","'/>   <Value data={yoy_text_fatal} column="difference" agg=sum fmt='####' /> <Value data={yoy_text_fatal} column="difference_text"/> (<Delta data={yoy_text_fatal} column="percentage_change" fmt="+0%;-0%;0%" downIsGood=True neutralMin=-0.00 neutralMax=0.00/>) compared to the same period in <Value data={yoy_text_fatal} column="year_prior" fmt="####."/>
    - As of <Value data={last_record} column="latest_record"/> there <Value data={yoy_text_major_injury} column="has_have"/> been <Value data={yoy_text_major_injury} column="current_year_sum" agg=sum/> <Value data={yoy_text_major_injury} column="major_injury"/> for all modes in <Value data={yoy_text_major_injury} column="current_year" fmt='####","'/>   <Value data={yoy_text_major_injury} column="difference" agg=sum fmt='####' /> <Value data={yoy_text_major_injury} column="difference_text"/> (<Delta data={yoy_text_major_injury} column="percentage_change" fmt="+0%;-0%;0%" downIsGood=True neutralMin=-0.00 neutralMax=0.00/>) compared to the same period in <Value data={yoy_text_major_injury} column="year_prior" fmt="####."/>

<Details title="About this dashboard">

    The Fatal and Injury Crashes Dashboard can be used by the public to know more about injuries or fatalities product of a crash in the District of Columbia (DC).
    
    Adjust the Mode, Severity and Date filters to refine the results.

</Details>

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
        RIGHT(CAST(DATE_PART('year', LAST_RECORD) AS VARCHAR), 2) AS latest_record
    FROM crashes.crashes
    ORDER BY LAST_RECORD DESC
    LIMIT 1;
```

```sql barchart_mode
    WITH combinations AS (
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
        AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
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

```sql yoy_mode
    WITH modes_and_severities AS (
        SELECT DISTINCT 
            MODE
        FROM 
            crashes.crashes
    ), 
    current_year AS (
        SELECT 
            MODE,
            SUM(COUNT) as sum_count,
            EXTRACT(YEAR FROM current_date) as current_year
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY IN ${inputs.multi_severity.value} 
            AND REPORTDATE >= date_trunc('year', current_date)
        GROUP BY 
            MODE
    ), 
    prior_year AS (
        SELECT 
            MODE,
            SUM(COUNT) as sum_count
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY IN ${inputs.multi_severity.value} 
            AND REPORTDATE >= (date_trunc('year', current_date) - INTERVAL '1 year')
            AND REPORTDATE < (current_date - INTERVAL '1 year')
        GROUP BY 
            MODE
    ), 
    total_counts AS (
        SELECT 
            SUM(cy.sum_count) AS total_current_year,
            SUM(py.sum_count) AS total_prior_year
        FROM 
            current_year cy
        FULL JOIN 
            prior_year py 
        ON 
            cy.MODE = py.MODE
    )
    SELECT 
        mas.MODE,
        COALESCE(cy.sum_count, 0) as current_year_sum, 
        COALESCE(py.sum_count, 0) as prior_year_sum, 
        COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) as difference,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) = 0 THEN 
                NULL 
            WHEN COALESCE(py.sum_count, 0) != 0 THEN 
                ((COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)) / COALESCE(py.sum_count, 0)) 
            ELSE 
                NULL 
        END as percentage_change,
        EXTRACT(YEAR FROM current_date) as current_year,
        (total_current_year - total_prior_year) / NULLIF(total_prior_year, 0) AS total_percentage_change
    FROM 
        modes_and_severities mas
    LEFT JOIN 
        current_year cy 
    ON 
        mas.MODE = cy.MODE
    LEFT JOIN 
        prior_year py 
    ON 
        mas.MODE = py.MODE,
    total_counts
```

```sql yoy_severity
    WITH severities AS (
        SELECT DISTINCT 
            SEVERITY
        FROM 
            crashes.crashes
    ), 
    current_year AS (
        SELECT 
            SEVERITY,
            SUM(COUNT) as sum_count,
            EXTRACT(YEAR FROM current_date) as current_year
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY IN ${inputs.multi_severity.value} 
            AND REPORTDATE >= date_trunc('year', current_date)
        GROUP BY 
            SEVERITY
    ), 
    prior_year AS (
        SELECT 
            SEVERITY,
            SUM(COUNT) as sum_count
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY IN ${inputs.multi_severity.value} 
            AND REPORTDATE >= (date_trunc('year', current_date) - INTERVAL '1 year')
            AND REPORTDATE < (current_date - INTERVAL '1 year')
        GROUP BY 
            SEVERITY
    ),
    total_sums AS (
        SELECT
            SUM(cy.sum_count) as total_current_year_sum,
            SUM(py.sum_count) as total_prior_year_sum
        FROM 
            severities s
        LEFT JOIN 
            current_year cy 
        ON 
            s.SEVERITY = cy.SEVERITY
        LEFT JOIN 
            prior_year py 
        ON 
            s.SEVERITY = py.SEVERITY
        WHERE 
            cy.sum_count IS NOT NULL OR py.sum_count IS NOT NULL
    )
    SELECT 
        s.SEVERITY,
        cy.sum_count as current_year_sum, 
        py.sum_count as prior_year_sum, 
        cy.sum_count - py.sum_count as difference,
        CASE 
            WHEN cy.sum_count = 0 THEN 
                NULL
            WHEN py.sum_count != 0 THEN 
                ((cy.sum_count - py.sum_count) / py.sum_count) 
            ELSE 
                NULL 
        END as percentage_change,
        t.total_current_year_sum,
        t.total_prior_year_sum,
        CASE
            WHEN t.total_prior_year_sum != 0 THEN
                ((t.total_current_year_sum - t.total_prior_year_sum) / t.total_prior_year_sum)
            ELSE
                NULL
        END as total_percentage_change,
        EXTRACT(YEAR FROM current_date) as current_year
    FROM 
        severities s
    LEFT JOIN 
        current_year cy 
    ON 
        s.SEVERITY = cy.SEVERITY
    LEFT JOIN 
        prior_year py 
    ON 
        s.SEVERITY = py.SEVERITY
    JOIN
        total_sums t
    ON TRUE
    WHERE 
        cy.sum_count IS NOT NULL OR py.sum_count IS NOT NULL
```

```sql yoy_text_fatal
    WITH b AS (
        SELECT 
            date_trunc('year', current_date) AS current_year_start,
            date_trunc('year', current_date) - interval '1 year' AS prior_year_start,
            current_date - interval '1 year' AS prior_year_end,
            extract(year FROM current_date) AS current_year,
            extract(year FROM current_date - interval '1 year') AS year_prior
    )
    SELECT 
        'Fatal' AS severity,
        COALESCE(SUM(CASE 
            WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT 
            ELSE 0 
            END), 0) AS current_year_sum,
        COALESCE(SUM(CASE 
            WHEN cr.REPORTDATE >= b.prior_year_start 
                AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT 
            ELSE 0 
            END), 0) AS prior_year_sum,
        ABS(
            COALESCE(SUM(CASE 
                WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END), 0)
        - COALESCE(SUM(CASE 
                WHEN cr.REPORTDATE >= b.prior_year_start 
                    AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END), 0)
        ) AS difference,
        CASE 
        WHEN SUM(CASE 
                WHEN cr.REPORTDATE >= b.prior_year_start 
                AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END) != 0 
        THEN NULLIF(
            (SUM(CASE 
                    WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END) - 
            SUM(CASE 
                    WHEN cr.REPORTDATE >= b.prior_year_start 
                    AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END)
            )::numeric /
            SUM(CASE 
                    WHEN cr.REPORTDATE >= b.prior_year_start 
                    AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END)
            , 0)
        ELSE NULL 
        END AS percentage_change,
        CASE 
        WHEN (SUM(CASE WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END)
            - SUM(CASE WHEN cr.REPORTDATE >= b.prior_year_start 
                        AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END)) > 0 
        THEN 'an increase of'
        WHEN (SUM(CASE WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END)
            - SUM(CASE WHEN cr.REPORTDATE >= b.prior_year_start 
                        AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END)) < 0 
        THEN 'a decrease of'
        ELSE NULL 
        END AS percentage_change_text,
        CASE 
        WHEN (SUM(CASE WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END)
            - SUM(CASE WHEN cr.REPORTDATE >= b.prior_year_start 
                        AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END)) > 0 
        THEN 'more'
        WHEN (SUM(CASE WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END)
            - SUM(CASE WHEN cr.REPORTDATE >= b.prior_year_start 
                        AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END)) < 0 
        THEN 'fewer'
        ELSE 'no change'
        END AS difference_text,
        b.current_year,
        b.year_prior,
        CASE 
        WHEN SUM(CASE WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END) = 1 
        THEN 'has' 
        ELSE 'have' 
        END AS has_have,
        CASE 
        WHEN SUM(CASE WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END) = 1 
        THEN 'fatality' 
        ELSE 'fatalities'
        END AS fatality
    FROM 
        b
        INNER JOIN crashes.crashes AS cr
        ON cr.SEVERITY = 'Fatal'
    GROUP BY b.current_year_start, b.prior_year_start, b.prior_year_end, 
            b.current_year, b.year_prior;
```

```sql yoy_text_major_injury
    WITH b AS (
        SELECT 
            date_trunc('year', current_date) AS current_year_start,
            date_trunc('year', current_date) - interval '1 year' AS prior_year_start,
            current_date - interval '1 year' AS prior_year_end,
            extract(year FROM current_date) AS current_year,
            extract(year FROM current_date - interval '1 year') AS year_prior
    )
    SELECT 
        'Major' AS severity,
        COALESCE(SUM(CASE 
            WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT 
            ELSE 0 
            END), 0) AS current_year_sum,
        COALESCE(SUM(CASE 
            WHEN cr.REPORTDATE >= b.prior_year_start 
                AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT 
            ELSE 0 
            END), 0) AS prior_year_sum,
        ABS(
            COALESCE(SUM(CASE 
                WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END), 0)
        - COALESCE(SUM(CASE 
                WHEN cr.REPORTDATE >= b.prior_year_start 
                    AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END), 0)
        ) AS difference,
        CASE 
        WHEN SUM(CASE 
                WHEN cr.REPORTDATE >= b.prior_year_start 
                AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END) != 0 
        THEN NULLIF(
            (SUM(CASE 
                    WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END) - 
            SUM(CASE 
                    WHEN cr.REPORTDATE >= b.prior_year_start 
                    AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END)
            )::numeric /
            SUM(CASE 
                    WHEN cr.REPORTDATE >= b.prior_year_start 
                    AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END)
            , 0)
        ELSE NULL 
        END AS percentage_change,
        CASE 
        WHEN (SUM(CASE WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END)
            - SUM(CASE WHEN cr.REPORTDATE >= b.prior_year_start 
                        AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END)) > 0 
        THEN 'an increase of'
        WHEN (SUM(CASE WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END)
            - SUM(CASE WHEN cr.REPORTDATE >= b.prior_year_start 
                        AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END)) < 0 
        THEN 'a decrease of'
        ELSE NULL 
        END AS percentage_change_text,
        CASE 
        WHEN (SUM(CASE WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END)
            - SUM(CASE WHEN cr.REPORTDATE >= b.prior_year_start 
                        AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END)) > 0 
        THEN 'more'
        WHEN (SUM(CASE WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END)
            - SUM(CASE WHEN cr.REPORTDATE >= b.prior_year_start 
                        AND cr.REPORTDATE < b.prior_year_end THEN cr.COUNT ELSE 0 END)) < 0 
        THEN 'fewer'
        ELSE 'no change'
        END AS difference_text,
        b.current_year,
        b.year_prior,
        CASE 
        WHEN SUM(CASE WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END) = 1 
        THEN 'has' 
        ELSE 'have' 
        END AS has_have,
        CASE 
        WHEN SUM(CASE WHEN cr.REPORTDATE >= b.current_year_start THEN cr.COUNT ELSE 0 END) = 1 
        THEN 'major injurie' 
        ELSE 'major injuries'
        END AS major_injury
    FROM 
        b
        INNER JOIN crashes.crashes AS cr
        ON cr.SEVERITY = 'Major'
    GROUP BY b.current_year_start, b.prior_year_start, b.prior_year_end, 
            b.current_year, b.year_prior;
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
old sql yoy_text_fatal
    WITH modes_and_severities AS (
        SELECT DISTINCT 
            SEVERITY 
        FROM 
            crashes.crashes
    ), 
    current_year AS (
        SELECT 
            SEVERITY, 
            sum(COUNT) as sum_count,
            extract(year from current_date) as current_year
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY = 'Fatal'
            AND REPORTDATE >= date_trunc('year', current_date)
        GROUP BY 
            SEVERITY
    ), 
    prior_year AS (
        SELECT 
            SEVERITY, 
            sum(COUNT) as sum_count,
            extract(year from current_date - interval '1 year') as year_prior
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY = 'Fatal'
            AND REPORTDATE >= (date_trunc('year', current_date) - interval '1 year')
            AND REPORTDATE < (current_date - interval '1 year')
        GROUP BY 
            SEVERITY
    )
    SELECT 
        mas.SEVERITY, 
        COALESCE(cy.sum_count, 0) as current_year_sum, 
        COALESCE(py.sum_count, 0) as prior_year_sum, 
        COALESCE(ABS(COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)), 0) AS difference,
        CASE 
            WHEN COALESCE(py.sum_count, 0) != 0 AND COALESCE(cy.sum_count, 0) != 0 THEN 
                CASE 
                    WHEN ((COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)) / COALESCE(py.sum_count, 0)) = 0 THEN NULL
                    ELSE ((COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)) / COALESCE(py.sum_count, 0))
                END
            ELSE NULL 
        END as percentage_change,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) > 0 THEN 'an increase of'
            WHEN COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) < 0 THEN 'a decrease of'
            ELSE NULL 
        END as percentage_change_text,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) > 0 THEN 'more'
            WHEN COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) < 0 THEN 'fewer'
            ELSE 'no change' 
        END as difference_text,
        extract(year from current_date) as current_year,
        COALESCE(py.year_prior, extract(year from current_date - interval '1 year')) as year_prior,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) = 1 THEN 'has' 
            ELSE 'have' 
        END as has_have,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) = 1 THEN 'fatality' 
            ELSE 'fatalities' 
        END as fatality
    FROM 
        modes_and_severities mas
    LEFT JOIN 
        current_year cy 
    ON 
        mas.SEVERITY = cy.SEVERITY
    LEFT JOIN 
        prior_year py 
    ON 
        mas.SEVERITY = py.SEVERITY
-->

<DateRange
  start='2018-01-01'
  title="Select Time Period"
  name=date_range
  presetRanges={['Last 7 Days','Last 30 Days','Last 90 Days','Last 3 Months','Last 6 Months','Year to Today','Last Year','All Time']}
  defaultValue={'Year to Today'}
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
            echartsOptions={{animation: false}}
        />
        <Note>
            *Fatal only.
        </Note>
    </Group>
        <Group>
        <DataTable data={yoy_mode} totalRow=true sort="current_year_sum desc" wrapTitles=true rowShading=true title="Year Over Year Difference">
            <Column id=MODE wrap=true totalAgg="Total"/>
            <Column id=current_year_sum title={`${yoy_mode[0].current_year} YTD`} />
            <Column id=prior_year_sum title={`${yoy_mode[0].current_year - 1} YTD`}  />
            <Column id=difference contentType=delta downIsGood=True title="Diff"/>
            <Column id=percentage_change fmt=pct title="% Diff" totalAgg={yoy_mode[0].total_percentage_change} totalFmt=pct/> 
        </DataTable>
        <DataTable data={yoy_severity} totalRow=true sort="current_year_sum desc" wrapTitles=true rowShading=true>
            <Column id=SEVERITY wrap=true totalAgg="Total"/>
            <Column id=current_year_sum title={`${yoy_mode[0].current_year} YTD`} />
            <Column id=prior_year_sum title={`${yoy_mode[0].current_year - 1} YTD`}  />
            <Column id=difference contentType=delta downIsGood=True title="Diff"/>
            <Column id=percentage_change fmt=pct title="% Diff" totalAgg={yoy_mode[0].total_percentage_change} totalFmt=pct /> 
        </DataTable>
        <Note>
            The results for both tables will depend on your severity selection above; by default, it displays "Major" and "Fatal" severity.
        </Note>
        <Note>
            *Fatal only.
        </Note>
    </Group>
</Grid>

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

<!---
<LastRefreshed prefix="Data last updated" printShowDate=True fmt='mmmm d, yyyy'/>
-->