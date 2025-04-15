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

```sql smd_yoy
    WITH unique_smd AS (
        SELECT 
            SMD 
        FROM 
            smd.smd_2023 
        GROUP BY 
            SMD
    ),
    current_year AS (
        SELECT 
            crashes.SMD, 
            SUM(crashes.COUNT) AS sum_count,
            EXTRACT(YEAR FROM current_date) AS current_year
        FROM 
            crashes.crashes 
        JOIN 
            unique_smd ua 
            ON crashes.SMD = ua.SMD
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.MODE IN ${inputs.multi_mode_dd.value}
            AND crashes.REPORTDATE >= DATE_TRUNC('year', current_date)
        GROUP BY 
            crashes.SMD
    ), 
    prior_year AS (
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
            AND crashes.REPORTDATE >= (DATE_TRUNC('year', current_date) - INTERVAL '1 year')
            AND crashes.REPORTDATE < (current_date - INTERVAL '1 year')
        GROUP BY 
            crashes.SMD
    )
    SELECT 
        mas.SMD,
        '/smd/' || mas.SMD AS link,
        COALESCE(cy.sum_count, 0) AS current_year_sum, 
        COALESCE(py.sum_count, 0) AS prior_year_sum, 
        COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) AS difference,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) = 0 THEN NULL
            WHEN COALESCE(py.sum_count, 0) != 0 THEN ((COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)) / COALESCE(py.sum_count, 0)) 
            WHEN COALESCE(py.sum_count, 0) != 0 AND COALESCE(cy.sum_count, 0) = 0 THEN -1
            ELSE NULL 
        END AS percentage_change,
        EXTRACT(YEAR FROM current_date) AS current_year
    FROM 
        unique_smd mas
    LEFT JOIN 
        current_year cy 
        ON mas.SMD = cy.SMD
    LEFT JOIN 
        prior_year py 
        ON mas.SMD = py.SMD;
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
  presetRanges={['Last 7 Days','Last 30 Days','Last 90 Days','Last 3 Months','Last 6 Months','Year to Today','Last Year','All Time']}
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
          height=470
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
        <DataTable data={smd_yoy} sort="current_year_sum desc" title="Year Over Year Difference" search=true wrapTitles=true rowShading=true link=link>
            <Column id=SMD title="SMD"/>
            <Column id=current_year_sum title={`${smd_yoy[0].current_year} YTD`} />
            <Column id=prior_year_sum title={`${smd_yoy[0].current_year - 1} YTD`}  />
            <Column id=difference title="Diff" contentType=delta downIsGood=True />
            <Column id=percentage_change fmt=pct0 title="% Diff"/> 
        </DataTable>
        <Note>
            The table is sorted in descending order by default based on the <Value data={smd_yoy} column="current_year" fmt='####'/> YTD injuries.
         </Note>
    </Group>
</Grid>