---
title: Injuries by Ward
#queries:
#   - anc_link: ward_link.sql
sidebar_position: 3
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

```sql unique_wards
select 
    NAME,
    WARD_ID
from wards.wards_2022
group by all
```

```sql unique_hin
select 
    GIS_ID,
    ROUTENAME
from hin.hin
group by all
```

```sql ward_map
    SELECT
        w.WARD_ID AS WARD,
        --CAST(w.WARD_ID AS INTEGER) AS link,
        COALESCE(SUM(c.COUNT), 0) AS Injuries
    FROM
        wards.wards_2022 w
    LEFT JOIN
        crashes.crashes c
    ON
        w.WARD_ID = c.WARD
        AND c.MODE IN ${inputs.multi_mode_dd.value}
        AND c.SEVERITY IN ${inputs.multi_severity.value}
        AND c.REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
    GROUP BY
        w.WARD_ID
    ORDER BY
        w.WARD_ID;
```

```sql ward_yoy
    WITH unique_ward AS (
        SELECT 
            WARD_ID AS WARD 
        FROM 
            wards.wards_2022
        GROUP BY 
            WARD_ID
    ),
    current_year AS (
        SELECT 
            crashes.WARD, 
            SUM(crashes.COUNT) AS sum_count,
            EXTRACT(YEAR FROM current_date) AS current_year
        FROM 
            crashes.crashes 
        JOIN 
            unique_ward ua 
        ON crashes.WARD = ua.WARD
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.MODE IN ${inputs.multi_mode_dd.value}
            AND crashes.REPORTDATE >= DATE_TRUNC('year', current_date)
        GROUP BY 
            crashes.WARD
    ), 
    prior_year AS (
        SELECT 
            crashes.WARD, 
            SUM(crashes.COUNT) AS sum_count
        FROM 
            crashes.crashes 
        JOIN 
            unique_ward ua 
        ON crashes.WARD = ua.WARD
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.MODE IN ${inputs.multi_mode_dd.value}
            AND crashes.REPORTDATE >= (DATE_TRUNC('year', current_date) - INTERVAL '1 year')
            AND crashes.REPORTDATE < (current_date - INTERVAL '1 year')
        GROUP BY 
            crashes.WARD
    ),
    totals AS (
        SELECT 
            SUM(COALESCE(cy.sum_count, 0)) AS current_year_total,
            SUM(COALESCE(py.sum_count, 0)) AS prior_year_total
        FROM 
            unique_ward mas
        LEFT JOIN 
            current_year cy 
        ON mas.WARD = cy.WARD
        LEFT JOIN 
            prior_year py 
        ON mas.WARD = py.WARD
    )
    SELECT 
        mas.WARD,
        --CAST(mas.WARD AS INTEGER) AS link,
        COALESCE(cy.sum_count, 0) AS current_year_sum, 
        COALESCE(py.sum_count, 0) AS prior_year_sum, 
        COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) AS difference,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) = 0 THEN NULL
            WHEN COALESCE(py.sum_count, 0) != 0 THEN ((COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)) / COALESCE(py.sum_count, 0)) 
            WHEN COALESCE(py.sum_count, 0) != 0 AND COALESCE(cy.sum_count, 0) = 0 THEN -1
            ELSE NULL 
        END AS percentage_change,
        EXTRACT(YEAR FROM current_date) AS current_year,
        CASE 
            WHEN totals.prior_year_total != 0 THEN (
                (totals.current_year_total - totals.prior_year_total) / totals.prior_year_total
            )
            ELSE NULL
        END AS total_percentage_change
    FROM 
        unique_ward mas
    LEFT JOIN 
        current_year cy ON mas.WARD = cy.WARD
    LEFT JOIN 
        prior_year py ON mas.WARD = py.WARD
    CROSS JOIN 
        totals;
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
    defaultValue={['Fatal', 'Major']}
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
        <BaseMap
            height=470
            startingZoom=11
            title="Wards"
        >
        <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00 ignoreZoom=true
            tooltip={[
                {id: 'ROUTENAME'}
            ]}
        />
        <Areas data={ward_map} geoJsonUrl='/Wards_from_2022.geojson' geoId=WARD_ID areaCol=WARD value=Injuries min=0 opacity=0.7 borderWidth=1 borderColor='#A9A9A9'
            tooltip={[
                {id:'WARD', title:"Ward", valueClass: 'text-base font-semibold', fieldClass: 'text-base font-semibold'},
                {id:'Injuries'}
            ]}
        />
        </BaseMap>
        <Note>
            The purple lines represent DC's High Injury Network
        </Note>
    </Group>
    <Group>
        <DataTable data={ward_yoy} sort="current_year_sum desc" title="Year Over Year Difference" totalRow=true wrapTitles=true rowShading=true>
            <Column id=WARD title="Ward" totalAgg="Total"/>
            <Column id=current_year_sum title={`${ward_yoy[0].current_year} YTD`} />
            <Column id=prior_year_sum title={`${ward_yoy[0].current_year - 1} YTD`}  />
            <Column id=difference title="Diff" contentType=delta downIsGood=True />
            <Column id=percentage_change fmt=pct title="% Diff" totalAgg={ward_yoy[0].total_percentage_change} totalFmt=pct/> 
        </DataTable>
        <Note>
            The table is sorted in descending order by default based on the <Value data={ward_yoy} column="current_year" fmt='####'/> YTD injuries.
         </Note>
    </Group>
</Grid>