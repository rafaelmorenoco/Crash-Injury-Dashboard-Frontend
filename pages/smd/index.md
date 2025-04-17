---
title: Injuries by SMD
queries:
   - smd_link: smd_link.sql
sidebar_position: 5
---

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

```sql unique_smd
select 
    SMD
from smd.smd_2023
group by 1
```

```sql period_comp_smd
    WITH 
        report_date_range AS (
            SELECT
                CASE 
                    WHEN '${inputs.date_range.end}' = CURRENT_DATE THEN 
                        (SELECT MAX(REPORTDATE) FROM crashes.crashes)
                    ELSE 
                        '${inputs.date_range.end}'::DATE
                END as end_date,
                '${inputs.date_range.start}'::DATE as start_date
        ),
        date_info AS (
            SELECT
                start_date,
                end_date,
                LPAD(CAST(EXTRACT(MONTH FROM start_date) AS VARCHAR), 2, '0') || '/' ||
                LPAD(CAST(EXTRACT(DAY FROM start_date) AS VARCHAR), 2, '0') || '/' ||
                RIGHT(CAST(EXTRACT(YEAR FROM start_date) AS VARCHAR), 2) || '-' ||
                LPAD(CAST(EXTRACT(MONTH FROM end_date) AS VARCHAR), 2, '0') || '/' ||
                LPAD(CAST(EXTRACT(DAY FROM end_date) AS VARCHAR), 2, '0') || '/' ||
                RIGHT(CAST(EXTRACT(YEAR FROM end_date) AS VARCHAR), 2) as date_range_label,
                (end_date - start_date) as date_range_days
            FROM report_date_range
        ),
        unique_smd AS (
            SELECT 
                SMD 
            FROM 
                smd.smd_2023 
            GROUP BY 
                SMD
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
                AND crashes.REPORTDATE >= (SELECT start_date FROM date_info)
                AND crashes.REPORTDATE <= (SELECT end_date FROM date_info)
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
                AND crashes.REPORTDATE >= ((SELECT start_date FROM date_info) - INTERVAL '1 year')
                AND crashes.REPORTDATE <= ((SELECT end_date FROM date_info) - INTERVAL '1 year')
            GROUP BY 
                crashes.SMD
        ),
        prior_date_info AS (
            SELECT
                (SELECT start_date FROM date_info) - INTERVAL '1 year' as prior_start_date,
                (SELECT end_date FROM date_info) - INTERVAL '1 year' as prior_end_date
        ),
        prior_date_label AS (
            SELECT
                LPAD(CAST(EXTRACT(MONTH FROM prior_start_date) AS VARCHAR), 2, '0') || '/' ||
                LPAD(CAST(EXTRACT(DAY FROM prior_start_date) AS VARCHAR), 2, '0') || '/' ||
                RIGHT(CAST(EXTRACT(YEAR FROM prior_start_date) AS VARCHAR), 2) || '-' ||
                LPAD(CAST(EXTRACT(MONTH FROM prior_end_date) AS VARCHAR), 2, '0') || '/' ||
                LPAD(CAST(EXTRACT(DAY FROM prior_end_date) AS VARCHAR), 2, '0') || '/' ||
                RIGHT(CAST(EXTRACT(YEAR FROM prior_end_date) AS VARCHAR), 2) as prior_date_range_label
            FROM prior_date_info
        )
        SELECT 
            mas.SMD,
            '/smd/' || mas.SMD AS link,
            COALESCE(cp.sum_count, 0) AS current_period_sum, 
            COALESCE(pp.sum_count, 0) AS prior_period_sum, 
            COALESCE(cp.sum_count, 0) - COALESCE(pp.sum_count, 0) AS difference,
            CASE 
                WHEN COALESCE(cp.sum_count, 0) = 0 THEN NULL
                WHEN COALESCE(pp.sum_count, 0) != 0 THEN ((COALESCE(cp.sum_count, 0) - COALESCE(pp.sum_count, 0)) / COALESCE(pp.sum_count, 0)) 
                WHEN COALESCE(pp.sum_count, 0) != 0 AND COALESCE(cp.sum_count, 0) = 0 THEN -1
                ELSE NULL 
            END AS percentage_change,
            (SELECT date_range_label FROM date_info) as current_period_range,
            (SELECT prior_date_range_label FROM prior_date_label) as prior_period_range
        FROM 
            unique_smd mas
        LEFT JOIN 
            current_period cp 
            ON mas.SMD = cp.SMD
        LEFT JOIN 
            prior_period pp 
            ON mas.SMD = pp.SMD;
```

```sql smd_map
    SELECT
        a.SMD,
        COALESCE(SUM(c.COUNT), 0) AS Injuries,
        '/smd/' || a.SMD AS link
    FROM
        smd.smd_2023 a
    LEFT JOIN
        crashes.crashes c ON a.SMD = c.SMD
        AND c.MODE IN ${inputs.multi_mode_dd.value}
        AND c.SEVERITY IN ${inputs.multi_severity.value}
        AND c.REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
    GROUP BY
        a.SMD
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
  start='2018-01-01'
  title="Select Time Period"
  name=date_range
  presetRanges={['Month to Today','Last Month','Year to Today','Last Year']}
  defaultValue={'Year to Today'}
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

<Note>
   Select an SMD to zoom in and see details about crash-related injuries within that SMD.
</Note>

<Grid cols=2>
    <Group>
        <BaseMap
          height=450
          startingZoom=11
          title="SMD"
        >
        <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00 ignoreZoom=true
            tooltip={[
                {id: 'ROUTENAME'}
            ]}
        />
        <Areas data={smd_map} geoJsonUrl='/smd_2023.geojson' geoId=SMD areaCol=SMD value=Injuries link=link min=0 opacity=0.7 borderWidth=1 borderColor='#A9A9A9'/>
        </BaseMap>
        <Note>
            The purple lines represent DC's High Injury Network
        </Note>
    </Group>    
    <Group>
        <DataTable data={period_comp_smd} sort="current_period_sum desc" title="Selected Period Comparison" search=true wrapTitles=true rowShading=true link=link>
            <Column id=SMD title="SMD"/>
            <Column id=current_period_sum title={`${period_comp_smd[0].current_period_range}`} />
            <Column id=prior_period_sum title={`${period_comp_smd[0].prior_period_range}`}  />
            <Column id=difference title="Diff" contentType=delta downIsGood=True />
            <Column id=percentage_change fmt=pct0 title="% Diff"/> 
        </DataTable>
        <Note>
            The table is sorted in descending order by default based on the count of injuries for the selected period.
         </Note>
    </Group>
</Grid>