---
title: Injuries by ANC & Ward
queries:
   - anc_link: anc_link.sql
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

```sql unique_anc
select 
    ANC
from anc.anc_2023
group by 1
```

```sql unique_smd
select 
    SMD
from smd.smd_2023
group by 1
```

```sql anc_map
    SELECT
        a.ANC,
        COALESCE(SUM(c.COUNT), 0) AS Injuries,
        '/anc/' || a.ANC AS link
    FROM
        anc.anc_2023 a
    LEFT JOIN
        crashes.crashes c ON a.ANC = c.ANC
        AND c.MODE IN ${inputs.multi_mode_dd.value}
        AND c.SEVERITY IN ${inputs.multi_severity.value}
        AND c.REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
    GROUP BY
        a.ANC
```

```sql ward_map
    SELECT
        w.WARD_ID AS WARD,
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

```sql anc_yoy
    WITH unique_anc AS (
        SELECT 
            ANC 
        FROM 
            anc.anc_2023 
        GROUP BY 
            ANC
    ),
    current_year AS (
        SELECT 
            crashes.ANC, 
            sum(crashes.COUNT) as sum_count,
            extract(year from current_date) as current_year
        FROM 
            crashes.crashes 
        JOIN 
            unique_anc ua 
        ON 
            crashes.ANC = ua.ANC
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.REPORTDATE >= date_trunc('year', current_date)
        GROUP BY 
            crashes.ANC
    ), 
    prior_year AS (
        SELECT 
            crashes.ANC, 
            sum(crashes.COUNT) as sum_count
        FROM 
            crashes.crashes 
        JOIN 
            unique_anc ua 
        ON 
            crashes.ANC = ua.ANC
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.REPORTDATE >= (date_trunc('year', current_date) - interval '1 year')
            AND crashes.REPORTDATE < (current_date - interval '1 year')
        GROUP BY 
            crashes.ANC
    )
    SELECT 
        mas.ANC,
        '/anc/' || mas.ANC AS link,
        COALESCE(cy.sum_count, 0) as current_year_sum, 
        COALESCE(py.sum_count, 0) as prior_year_sum, 
        COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) as difference,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) = 0 THEN NULL
            WHEN COALESCE(py.sum_count, 0) != 0 THEN ((COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)) / COALESCE(py.sum_count, 0)) 
            WHEN COALESCE(py.sum_count, 0) != 0 AND COALESCE(cy.sum_count, 0) = 0 THEN -1
            ELSE NULL 
        END as percentage_change,
        extract(year from current_date) as current_year
    FROM 
        unique_anc mas
    LEFT JOIN 
        current_year cy 
    ON 
        mas.ANC = cy.ANC
    LEFT JOIN 
        prior_year py 
    ON 
        mas.ANC = py.ANC;
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
            sum(crashes.COUNT) as sum_count,
            extract(year from current_date) as current_year
        FROM 
            crashes.crashes 
        JOIN 
            unique_ward ua 
        ON 
            crashes.WARD = ua.WARD
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.REPORTDATE >= date_trunc('year', current_date)
        GROUP BY 
            crashes.WARD
    ), 
    prior_year AS (
        SELECT 
            crashes.WARD, 
            sum(crashes.COUNT) as sum_count
        FROM 
            crashes.crashes 
        JOIN 
            unique_ward ua 
        ON 
            crashes.WARD = ua.WARD
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.REPORTDATE >= (date_trunc('year', current_date) - interval '1 year')
            AND crashes.REPORTDATE < (current_date - interval '1 year')
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
        ON 
            mas.WARD = cy.WARD
        LEFT JOIN 
            prior_year py 
        ON 
            mas.WARD = py.WARD
    )
    SELECT 
        mas.WARD,
        COALESCE(cy.sum_count, 0) as current_year_sum, 
        COALESCE(py.sum_count, 0) as prior_year_sum, 
        COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) as difference,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) = 0 THEN NULL
            WHEN COALESCE(py.sum_count, 0) != 0 THEN ((COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)) / COALESCE(py.sum_count, 0)) 
            WHEN COALESCE(py.sum_count, 0) != 0 AND COALESCE(cy.sum_count, 0) = 0 THEN -1
            ELSE NULL 
        END as percentage_change,
        extract(year from current_date) as current_year,
        CASE 
            WHEN totals.prior_year_total != 0 THEN (
                (totals.current_year_total - totals.prior_year_total) / totals.prior_year_total
            )
            ELSE NULL
        END AS total_percentage_change
    FROM 
        unique_ward mas
    LEFT JOIN 
        current_year cy 
    ON 
        mas.WARD = cy.WARD
    LEFT JOIN 
        prior_year py 
    ON 
        mas.WARD = py.WARD
    CROSS JOIN 
        totals;
```

<DateRange
  start='2018-01-01'
  title="Select Time Period"
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

<Note>
    Select an ANC to zoom in and see more details about the injuries resulting from a crash within its SMDs."
</Note>
<Grid cols=2>
    <Group>
        <BaseMap
            height=470
            startingZoom=11
            title="ANC"
        >
        <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00 ignoreZoom=true
            tooltip={[
                {id: 'ROUTENAME'}
            ]}
        />
        <Areas data={anc_map} geoJsonUrl='/anc_2023.geojson' geoId=ANC areaCol=ANC value=Injuries link=link min=0 opacity=0.7 borderWidth=1 borderColor='#A9A9A9'/>
        </BaseMap>
        <Note>
            The purple lines represent DC's High Injury Network
        </Note>
    </Group>
    <Group>
        <DataTable data={anc_yoy} sort="current_year_sum desc" title="Year Over Year Difference" search=true wrapTitles=true rowShading=true link=link>
            <Column id=ANC title="ANC"/>
            <Column id=current_year_sum title={`${anc_yoy[0].current_year} YTD`} />
            <Column id=prior_year_sum title={`${anc_yoy[0].current_year - 1} YTD`}  />
            <Column id=difference title="Diff" contentType=delta downIsGood=True />
            <Column id=percentage_change fmt=pct0 title="% Diff"/> 
        </DataTable>
        <Note>
            The table is sorted in descending order by default based on the <Value data={anc_yoy} column="current_year" fmt='####'/> YTD injuries.
         </Note>
    </Group>
</Grid>

## Injuries by Ward

<Grid cols=2>
    <Group>
        <BaseMap
            height=470
            startingZoom=11
            title="Ward"
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