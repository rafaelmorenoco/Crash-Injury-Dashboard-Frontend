---
title: Last 7 Days
sidebar_position: 6
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

```sql last_record
    SELECT
        LPAD(CAST(DATE_PART('month', LAST_RECORD) AS VARCHAR), 2, '0') || '/' ||
        LPAD(CAST(DATE_PART('day', LAST_RECORD) AS VARCHAR), 2, '0') || '/' ||
        RIGHT(CAST(DATE_PART('year', LAST_RECORD) AS VARCHAR), 2) || ',' AS latest_record,
        LPAD(CAST(DATE_PART('month', LAST_UPDATE) AS VARCHAR), 2, '0') || '/' ||
        LPAD(CAST(DATE_PART('day', LAST_UPDATE) AS VARCHAR), 2, '0') || '/' ||
        RIGHT(CAST(DATE_PART('year', LAST_UPDATE) AS VARCHAR), 2) || ' ' ||
        LPAD(CAST(DATE_PART('hour', LAST_UPDATE) AS VARCHAR), 2, '0') || ':' ||
        LPAD(CAST(DATE_PART('minute', LAST_UPDATE) AS VARCHAR), 2, '0') || '.' AS latest_update
    FROM crashes.crashes
    ORDER BY LAST_RECORD DESC
    LIMIT 1;
```

```sql unique_hin
select 
    GIS_ID,
    ROUTENAME
from hin.hin
group by all
```

```sql unique_dc
select 
    CITY_NAME
from dc_boundary.dc_boundary
group by 1
```

```sql inc_map
    WITH latest AS (
        SELECT date_trunc('day', MAX(REPORTDATE)) AS end_date
        FROM crashes.crashes
    )
    SELECT 
        date_trunc('day', c.REPORTDATE) AS day,
        c.LATITUDE,
        c.LONGITUDE,
        SUBSTRING(c.MODE, 1, 3) || '-' || SUBSTRING(c.SEVERITY, 1) AS MODESEV,
        c.ADDRESS,
        c.GRID_ID,
        c.REPORTDATE,
        c.AGE,
        c.COUNT,
        STRFTIME('%m/%d %a', date_trunc('day', c.REPORTDATE)) AS WEEKDAY
    FROM crashes.crashes c
    CROSS JOIN latest l
    WHERE c.MODE IN ${inputs.multi_mode_dd.value}
    AND c.SEVERITY IN ${inputs.multi_severity.value}
    AND date_trunc('day', c.REPORTDATE) BETWEEN (l.end_date - 6) AND l.end_date
    ORDER BY day DESC;
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

The last 7 days with available data range from <Value data={inc_map} column="WEEKDAY" agg="min"/> to <Value data={inc_map} column="WEEKDAY" agg="max" />

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
        <Note>
            Each point on the map represents an injury. Injury incidents can overlap in the same spot.
        </Note>
        <BaseMap
            height=450
            startingZoom=11
        >
            <Points data={inc_map} lat=LATITUDE long=LONGITUDE pointName=MODE value=WEEKDAY ignoreZoom=true colorPalette={['#595cff','#6b76ff','#7d90ff','#90aaff','#a2c4ff','#b4deff','#c6f8ff']}
            tooltip={[
                {id:'MODESEV', showColumnName:false, fmt:'id', valueClass:'text-l font-semibold'},
                {id:'day', showColumnName:false, fmt:'mm/dd/yy'},
                {id:'ADDRESS', showColumnName:false, fmt:'id'}
            ]}
            />
            <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00/ ignoreZoom=true borderWidth=1.2
            tooltip={[
                {id: 'ROUTENAME'}
            ]}
            />
            <Areas data={unique_dc} geoJsonUrl='/dc_boundary.geojson' geoId=CITY_NAME areaCol=CITY_NAME opacity=0.5 borderColor=#000000 color=#1C00ff00/ 
            />
        </BaseMap>
        <Note>
            The purple lines represent DC's High Injury Network
        </Note>
    </Group>
    <Group>
        <DataTable data={inc_map} wrapTitles=true rowShading=true groupBy=WEEKDAY subtotals=true sort="WEEKDAY desc" totalRow=true accordionRowColor="#D3D3D3">
            <Column id=REPORTDATE title="Date" fmt='hh:mm' wrap=true totalAgg="Total"/>
            <Column id=MODESEV title="Mode-Sev" wrap=true/>
            <Column id=AGE title="Age" wrap=true totalAgg="-"/>
            <Column id=ADDRESS wrap=true/>
            <Column id=COUNT title="#" wrap=true/>
        </DataTable>
        <Note>
            The latest crash record in the dataset is from <Value data={last_record} column="latest_record"/> and the data was last updated on <Value data={last_record} column="latest_update"/> hrs.
        </Note>
    </Group>
</Grid>
