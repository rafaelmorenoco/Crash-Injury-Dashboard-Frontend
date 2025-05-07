---
queries:
   - anc_link: anc_link.sql
---

# ANC {params.ANC}

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

```sql unique_wards
select 
    WARD_ID
from wards.wards_2022
group by 1
```

```sql unique_hin
select 
    GIS_ID,
    ROUTENAME
from hin.hin
group by all
```

```sql unique_anc
select 
    ANC
from anc.anc_2023
where ANC = '${params.ANC}'
group by 1
```

```sql unique_smd
select 
    SMD
from smd.smd_2023
group by 1
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

```sql smd_map
WITH 
    report_date_range AS (
        SELECT
            CASE 
                WHEN '${inputs.date_range.end}'::DATE >= 
                     (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes)
                THEN (SELECT MAX(REPORTDATE) FROM crashes.crashes)
                ELSE '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
            END AS end_date,
            '${inputs.date_range.start}'::DATE AS start_date
    ),
    date_info AS (
        SELECT
            start_date,
            end_date,
            CASE 
                WHEN '${inputs.date_range.end}'::DATE > end_date::DATE
                    THEN strftime(start_date, '%m/%d/%y') || '-' || strftime(end_date, '%m/%d/%y')
                ELSE 
                    ''  -- Return a blank string instead of any other value
            END AS date_range_label,
            (end_date - start_date) AS date_range_days
        FROM report_date_range
    )
SELECT 
    smd_2023.SMD,
    '/smd/' || smd_2023.SMD AS link,
    COALESCE(subquery.Injuries, 0) AS Injuries,
    di.date_range_label
FROM smd.smd_2023 AS smd_2023
LEFT JOIN (
    SELECT
        SMD,
        SUM(COUNT) AS Injuries
    FROM 
        crashes.crashes
    WHERE 
        ANC = '${params.ANC}'
        AND MODE IN ${inputs.multi_mode_dd.value}
        AND SEVERITY IN ${inputs.multi_severity.value}
        AND REPORTDATE BETWEEN (SELECT start_date FROM report_date_range) AND (SELECT end_date FROM report_date_range)
        AND SMD IS NOT NULL
    GROUP BY 
        SMD
) AS subquery
    ON smd_2023.SMD = subquery.SMD
JOIN (
    SELECT DISTINCT SMD
    FROM crashes.crashes
    WHERE ANC = '${params.ANC}'
) AS smd_anc
    ON smd_2023.SMD = smd_anc.SMD
CROSS JOIN date_info di
ORDER BY smd_2023.SMD;
```

```sql period_comp_smd
WITH 
    report_date_range AS (
        SELECT
            CASE 
                WHEN '${inputs.date_range.end}'::DATE >= (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes)::DATE THEN 
                    (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE + INTERVAL '1 day'
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
                    AND '${inputs.date_range.end}'::DATE = end_date::DATE - INTERVAL '1 day'
                    THEN EXTRACT(YEAR FROM end_date)::VARCHAR || ' YTD' 
                WHEN '${inputs.date_range.end}'::DATE > end_date::DATE  - INTERVAL '1 day'
                    THEN strftime(start_date, '%m/%d/%y') || '-' || strftime(end_date, '%m/%d/%y')
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
                WHEN end_date > start_date + INTERVAL '5 year' THEN (SELECT 1/0) -- Force failure if > 5 years
                WHEN end_date > start_date + INTERVAL '4 year' THEN INTERVAL '5 year'
                WHEN end_date > start_date + INTERVAL '3 year' THEN INTERVAL '4 year'
                WHEN end_date > start_date + INTERVAL '2 year' THEN INTERVAL '3 year'
                WHEN end_date > start_date + INTERVAL '1 year' THEN INTERVAL '2 year'
                ELSE INTERVAL '1 year'
            END AS interval_offset
        FROM date_info
    ),
    unique_smd AS (
        SELECT 
            smd.SMD
        FROM 
            smd.smd_2023 smd
        JOIN 
            crashes.crashes crashes
        ON smd.SMD = crashes.SMD
        WHERE 
            crashes.ANC = '${params.ANC}'
        GROUP BY 
            smd.SMD
    ),
    current_period AS (
        SELECT 
            crashes.SMD, 
            SUM(crashes.COUNT) AS sum_count
        FROM 
            crashes.crashes 
        JOIN 
            unique_smd ua 
            ON crashes.SMD = ua.SMD
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.MODE IN ${inputs.multi_mode_dd.value}
            AND crashes.REPORTDATE BETWEEN (SELECT start_date FROM date_info)
                                        AND (SELECT end_date FROM date_info)
        GROUP BY 
            crashes.SMD
    ), 
    prior_period AS (
        SELECT 
            crashes.SMD, 
            SUM(crashes.COUNT) AS sum_count
        FROM 
            crashes.crashes 
        JOIN 
            unique_smd ua 
            ON crashes.SMD = ua.SMD
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.MODE IN ${inputs.multi_mode_dd.value}
            AND crashes.REPORTDATE BETWEEN (
                    (SELECT start_date FROM date_info) - (SELECT interval_offset FROM offset_period)
                ) AND (
                    (SELECT end_date FROM date_info) - (SELECT interval_offset FROM offset_period)
                )
        GROUP BY 
            crashes.SMD
    ),
    prior_date_info AS (
        SELECT
            (SELECT start_date FROM date_info) - (SELECT interval_offset FROM offset_period) AS prior_start_date,
            (SELECT end_date   FROM date_info) - (SELECT interval_offset FROM offset_period) AS prior_end_date
    ),
    prior_date_label AS (
        SELECT
            CASE 
                WHEN (SELECT start_date FROM date_info) = DATE_TRUNC('year', (SELECT end_date FROM date_info))
                    AND '${inputs.date_range.end}'::DATE = (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes)
                    THEN EXTRACT(YEAR FROM prior_end_date)::VARCHAR || ' YTD'
                WHEN '${inputs.date_range.end}'::DATE > (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes)
                    THEN strftime(prior_start_date, '%m/%d/%y') || '-' || strftime(prior_end_date, '%m/%d/%y')
                ELSE 
                    strftime(prior_start_date, '%m/%d/%y') || '-' || strftime(prior_end_date - INTERVAL '1 day', '%m/%d/%y')
            END AS prior_date_range_label
        FROM prior_date_info
    ),
    totals AS (
        SELECT 
            SUM(COALESCE(cp.sum_count, 0)) AS current_period_total,
            SUM(COALESCE(pp.sum_count, 0)) AS prior_period_total
        FROM 
            unique_smd mas
        LEFT JOIN current_period cp ON mas.SMD = cp.SMD
        LEFT JOIN prior_period pp ON mas.SMD = pp.SMD
    )
SELECT 
    mas.SMD,
    '/smd/' || mas.SMD AS link,
    COALESCE(cp.sum_count, 0) AS current_period_sum, 
    COALESCE(pp.sum_count, 0) AS prior_period_sum, 
    COALESCE(cp.sum_count, 0) - COALESCE(pp.sum_count, 0) AS difference,
    CASE 
        WHEN COALESCE(cp.sum_count, 0) = 0 THEN NULL
        WHEN COALESCE(pp.sum_count, 0) != 0 THEN 
            ((COALESCE(cp.sum_count, 0) - COALESCE(pp.sum_count, 0)) / COALESCE(pp.sum_count, 0))
        WHEN COALESCE(pp.sum_count, 0) != 0 AND COALESCE(cp.sum_count, 0) = 0 THEN -1
        ELSE NULL 
    END AS percentage_change,
    (SELECT date_range_label FROM date_info) AS current_period_range,
    (SELECT prior_date_range_label FROM prior_date_label) AS prior_period_range,
    CASE 
        WHEN totals.prior_period_total != 0 THEN (
            (totals.current_period_total - totals.prior_period_total) / totals.prior_period_total
        )
        ELSE NULL
    END AS total_percentage_change
FROM unique_smd mas
LEFT JOIN current_period cp ON mas.SMD = cp.SMD
LEFT JOIN prior_period pp ON mas.SMD = pp.SMD
CROSS JOIN totals;
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
  presetRanges={['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'Last 6 Months', 'Last 12 Months', 'Month to Today', 'Last Month', 'Year to Today', 'Last Year']}
  defaultValue="Year to Today"
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
    title="Select Road User"
    multiple=true
    selectAllByDefault=true
    description="*Only fatal"
/>

<Alert status="info">
The slection for <b>Severity</b> is: <b><Value data={mode_severity_selection} column="SEVERITY_SELECTION"/></b>. The slection for <b>Road User</b> is: <b><Value data={mode_severity_selection} column="MODE_SELECTION"/></b> <Info description="*Fatal only." color="primary" />
</Alert>

### Injuries by SMD within ANC {params.ANC}

<Grid cols=2>
    <Group>
        <Note>
            Select an SMD to zoom in and see more details about the crashes within it.
        </Note>
        <BaseMap
            height=500
            startingZoom=14
            title="{`${smd_map[0].date_range_label}`}"
        >
        <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00 ignoreZoom=true borderWidth=1.5
            tooltip={[
                {id: 'ROUTENAME'}
            ]}
        />
        <Areas data={smd_map} height=650 startingZoom=13 geoJsonUrl='/smd_2023.geojson' geoId=SMD areaCol=SMD value=Injuries min=0 borderWidth=1.5 borderColor='#A9A9A9' link=link
        />
        </BaseMap>
        <Note>
            The purple lines represent DC's High Injury Network
        </Note>
    </Group>
    <Group>
        <DataTable data={period_comp_smd} sort="current_period_sum desc" title="Selected Period Comparison" wrapTitles=true rowShading=true totalRow=true link=link>
            <Column id=SMD title="SMD" totalAgg={`ANC ${unique_anc[0].ANC} Total`}/>
            <Column id=current_period_sum title={`${period_comp_smd[0].current_period_range}`} />
            <Column id=prior_period_sum title={`${period_comp_smd[0].prior_period_range}`}  />
            <Column id=difference title="Diff" contentType=delta downIsGood=True />
            <Column id=percentage_change fmt='pct0' title="% Diff" totalAgg={period_comp_smd[0].total_percentage_change} totalFmt='pct0'/> 
        </DataTable>
        <Note>
            The latest crash record in the dataset is from <Value data={last_record} column="latest_record"/> and the data was last updated on <Value data={last_record} column="latest_update"/> hrs. This lag factors into prior period comparisons. The maximum comparison period is 5 years.
        </Note>
    </Group>
</Grid>