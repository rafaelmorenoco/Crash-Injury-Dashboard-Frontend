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
    NAME
from wards.wards_2022
group by 1
```

```sql unique_hex
select 
    GRID_ID
from hexgrid.crash_hexgrid
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

```sql smd_map
    SELECT 
        smd_2023.SMD,
        '/smd/' || smd_2023.SMD AS link,
        COALESCE(subquery.Injuries, 0) AS Injuries
    FROM 
        smd.smd_2023 AS smd_2023
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
            AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
            AND SMD IS NOT NULL
        GROUP BY 
            SMD
    ) AS subquery
    ON 
        smd_2023.SMD = subquery.SMD
    JOIN (
        SELECT DISTINCT SMD
        FROM crashes.crashes
        WHERE ANC = '${params.ANC}'
    ) AS smd_anc
    ON 
        smd_2023.SMD = smd_anc.SMD
    ORDER BY 
        smd_2023.SMD;
```

```sql smd_yoy
    WITH unique_smd AS (
        SELECT 
            smd.SMD
        FROM 
            smd.smd_2023 smd
        JOIN 
            crashes.crashes crashes
        ON 
            smd.SMD = crashes.SMD
        WHERE 
            crashes.ANC = '${params.ANC}'
        GROUP BY 
            smd.SMD
    ),
    current_year AS (
        SELECT 
            crashes.SMD, 
            SUM(crashes.COUNT) AS sum_count, 
            EXTRACT(YEAR FROM current_date) AS current_year
        FROM 
            crashes.crashes
        JOIN 
            unique_smd us 
        ON 
            crashes.SMD = us.SMD
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.REPORTDATE >= DATE_TRUNC('year', current_date)
            AND crashes.ANC = '${params.ANC}'
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
            unique_smd us 
        ON 
            crashes.SMD = us.SMD
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.REPORTDATE >= (DATE_TRUNC('year', current_date) - INTERVAL '1 year') 
            AND crashes.REPORTDATE < (CURRENT_DATE - INTERVAL '1 year')
            AND crashes.ANC = '${params.ANC}'
        GROUP BY 
            crashes.SMD
    ),
    totals AS (
        SELECT 
            SUM(COALESCE(cy.sum_count, 0)) AS current_year_total,
            SUM(COALESCE(py.sum_count, 0)) AS prior_year_total
        FROM 
            unique_smd mas
        LEFT JOIN 
            current_year cy 
        ON 
            mas.SMD = cy.SMD
        LEFT JOIN 
            prior_year py 
        ON 
            mas.SMD = py.SMD
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
        EXTRACT(YEAR FROM current_date) AS current_year,
        CASE 
            WHEN totals.prior_year_total != 0 THEN (
                (totals.current_year_total - totals.prior_year_total) / totals.prior_year_total
            )
            ELSE NULL
        END AS total_percentage_change
    FROM 
        unique_smd mas
    LEFT JOIN 
        current_year cy 
    ON 
        mas.SMD = cy.SMD
    LEFT JOIN 
        prior_year py 
    ON 
        mas.SMD = py.SMD
    CROSS JOIN 
        totals;
```

<DateRange
  start='2020-01-01'
  name=date_range
  presetRanges={['Last 7 Days','Last 30 Days','Last 90 Days','Last 3 Months','Last 6 Months','Year to Date','Last Year','All Time']}
  defaultValue={'Year to Date'}
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

### Injuries by SMD within ANC {params.ANC}

<Grid cols=2>
    <Group>
        <Note>
            Select an SMD to zoom in and see more details about the crashes within it.
        </Note>
        <BaseMap
            height=500
            startingZoom=14
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
        <DataTable data={smd_yoy} sort="current_year_sum desc" title="Year Over Year Difference" wrapTitles=true rowShading=true totalRow=true link=link>
            <Column id=SMD title="SMD" totalAgg={`ANC ${unique_anc[0].ANC} Total`}/>
            <Column id=current_year_sum title={`${smd_yoy[0].current_year} YTD`} />
            <Column id=prior_year_sum title={`${smd_yoy[0].current_year - 1} YTD`}  />
            <Column id=difference title="Diff" contentType=delta downIsGood=True />
            <Column id=percentage_change fmt=pct0 title="% Diff" totalAgg={smd_yoy[0].total_percentage_change} totalFmt=pct0/> 
        </DataTable>
        <Note>
            The table is sorted in descending order by default based on the <Value data={smd_yoy} column="current_year" fmt='####'/> YTD injuries.
        </Note>
    </Group>
</Grid>