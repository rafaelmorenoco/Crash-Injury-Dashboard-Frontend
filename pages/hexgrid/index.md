---
title: Injuries Heatmap
queries:
   - hex: hex.sql
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

```sql day_time
    WITH reference AS (
        SELECT
            dow.day_of_week,
            dow.day_number,
            hr.hour_number
        FROM 
            (VALUES 
                ('Sun', 0), ('Mon', 1), ('Tue', 2), 
                ('Wed', 3), ('Thu', 4), ('Fri', 5), ('Sat', 6)
            ) AS dow(day_of_week, day_number),
            GENERATE_SERIES(0, 23) AS hr(hour_number)
    ),
    count_data AS (
        SELECT
            CASE
                WHEN DATE_PART('dow', REPORTDATE) = 0 THEN 'Sun'
                WHEN DATE_PART('dow', REPORTDATE) = 1 THEN 'Mon'
                WHEN DATE_PART('dow', REPORTDATE) = 2 THEN 'Tue'
                WHEN DATE_PART('dow', REPORTDATE) = 3 THEN 'Wed'
                WHEN DATE_PART('dow', REPORTDATE) = 4 THEN 'Thu'
                WHEN DATE_PART('dow', REPORTDATE) = 5 THEN 'Fri'
                WHEN DATE_PART('dow', REPORTDATE) = 6 THEN 'Sat'
            END AS day_of_week,
            CASE
                WHEN DATE_PART('dow', REPORTDATE) = 1 THEN 0
                WHEN DATE_PART('dow', REPORTDATE) = 2 THEN 1
                WHEN DATE_PART('dow', REPORTDATE) = 3 THEN 2
                WHEN DATE_PART('dow', REPORTDATE) = 4 THEN 3
                WHEN DATE_PART('dow', REPORTDATE) = 5 THEN 4
                WHEN DATE_PART('dow', REPORTDATE) = 6 THEN 5
                WHEN DATE_PART('dow', REPORTDATE) = 0 THEN 6
            END AS day_number,
            LPAD(CAST(DATE_PART('hour', REPORTDATE) AS VARCHAR), 2, '0') AS hour_number,
            SUM(COUNT) AS sum_count
        FROM crashes.crashes
        WHERE MODE IN ${inputs.multi_mode_dd.value}
        AND SEVERITY IN ${inputs.multi_severity.value}
        AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
        GROUP BY day_of_week, day_number, hour_number
    )

    SELECT
        r.day_of_week,
        r.day_number,
        LPAD(r.hour_number::TEXT, 2, '0') AS hour_number,
        COALESCE(cd.sum_count, 0) AS sum_count
    FROM reference r
    LEFT JOIN count_data cd
    ON r.day_of_week = cd.day_of_week
    AND r.hour_number = cd.hour_number
    ORDER BY r.day_number, r.hour_number;
```

```sql time
    WITH reference AS (
        SELECT
            hr.hour_number
        FROM 
            GENERATE_SERIES(0, 23) AS hr(hour_number)
    ),
    count_data AS (
        SELECT
            LPAD(CAST(DATE_PART('hour', REPORTDATE) AS VARCHAR), 2, '0') AS hour_number,
            SUM(COUNT) AS sum_count
        FROM crashes.crashes
        WHERE MODE IN ${inputs.multi_mode_dd.value}
        AND SEVERITY IN ${inputs.multi_severity.value}
        AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
        GROUP BY hour_number
    )

    SELECT
        'Total' AS Total,
        LPAD(r.hour_number::TEXT, 2, '0') AS hour_number,
        COALESCE(cd.sum_count, 0) AS sum_count
    FROM reference r
    LEFT JOIN count_data cd
    ON r.hour_number = cd.hour_number
    ORDER BY r.hour_number;
```

```sql day
    WITH reference AS (
        SELECT
            dow.day_of_week,
            dow.day_number,
            'Total' AS total
        FROM 
            (VALUES 
                ('Sun', 0), ('Mon', 1), ('Tue', 2), 
                ('Wed', 3), ('Thu', 4), ('Fri', 5), ('Sat', 6)
            ) AS dow(day_of_week, day_number)
    ),
    count_data AS (
        SELECT
            CASE
                WHEN DATE_PART('dow', REPORTDATE) = 0 THEN 'Sun'
                WHEN DATE_PART('dow', REPORTDATE) = 1 THEN 'Mon'
                WHEN DATE_PART('dow', REPORTDATE) = 2 THEN 'Tue'
                WHEN DATE_PART('dow', REPORTDATE) = 3 THEN 'Wed'
                WHEN DATE_PART('dow', REPORTDATE) = 4 THEN 'Thu'
                WHEN DATE_PART('dow', REPORTDATE) = 5 THEN 'Fri'
                WHEN DATE_PART('dow', REPORTDATE) = 6 THEN 'Sat'
            END AS day_of_week,
            CASE
                WHEN DATE_PART('dow', REPORTDATE) = 1 THEN 0
                WHEN DATE_PART('dow', REPORTDATE) = 2 THEN 1
                WHEN DATE_PART('dow', REPORTDATE) = 3 THEN 2
                WHEN DATE_PART('dow', REPORTDATE) = 4 THEN 3
                WHEN DATE_PART('dow', REPORTDATE) = 5 THEN 4
                WHEN DATE_PART('dow', REPORTDATE) = 6 THEN 5
                WHEN DATE_PART('dow', REPORTDATE) = 0 THEN 6
            END AS day_number,
            SUM(COUNT) AS sum_count
        FROM crashes.crashes
        WHERE MODE IN ${inputs.multi_mode_dd.value}
        AND SEVERITY IN ${inputs.multi_severity.value}
        AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
        GROUP BY day_of_week, day_number
    )

    SELECT
        r.day_of_week,
        r.day_number,
        r.total,
        COALESCE(cd.sum_count, 0) AS sum_count
    FROM reference r
    LEFT JOIN count_data cd
    ON r.day_of_week = cd.day_of_week
    ORDER BY r.day_number;
```

```sql hex_map
    SELECT
        h.GRID_ID,
        COALESCE(SUM(c.COUNT), 0) AS Injuries,
        '/hexgrid/' || h.GRID_ID AS link
    FROM
        hexgrid.crash_hexgrid h
    LEFT JOIN
        crashes.crashes c ON h.GRID_ID = c.GRID_ID
        AND c.MODE IN ${inputs.multi_mode_dd.value}
        AND c.SEVERITY IN ${inputs.multi_severity.value}
        AND c.REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
    GROUP BY
        h.GRID_ID
```

```sql intersections_table
    SELECT
        GRID_ID,
        STRING_AGG(
            COALESCE(NULLIF(INTERSECTIONNAME, ''), NULLIF(ROUTENAME, ''))
            , ' - '
        ) AS INTERSECTIONNAMES,
        '/hexgrid/' || GRID_ID AS link
    FROM intersections.intersections
    GROUP BY GRID_ID;
```

```sql modes_selected
    SELECT
        STRING_AGG(DISTINCT MODE, ', ') AS MODE_SELECTED,
        CASE 
            WHEN COUNT(DISTINCT MODE) > 1 THEN 'modes are:'
            ELSE 'mode is:'
        END AS PLURAL_SINGULAR
    FROM
        crashes.crashes
    WHERE
        MODE IN ${inputs.multi_mode_dd.value};
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

<Alert status="info">
The selected transportation <Value data={modes_selected} column="PLURAL_SINGULAR"/> <Value data={modes_selected} column="MODE_SELECTED"/>
</Alert>

<Grid cols=2>
    <Group>
        <Note>
            Select a hexagon to zoom in and view more details about the injuries resulting from a crash within it.
        </Note>
        <BaseMap
            height=560
            startingZoom=12
        >
            <Areas data={hex_map} geoJsonUrl='/crash-hexgrid.geojson' geoId=GRID_ID areaCol=GRID_ID value=Injuries link=link min=0 opacity=0.7 />
            <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00/ ignoreZoom=true 
            tooltip={[
                {id: 'ROUTENAME'}
            ]}
            />
        </BaseMap>
        <Note>
        The purple lines represent DC's High Injury Network  
        </Note>
    </Group>
    <Group>
        <Heatmap 
            data={day}
            title="Injuries by Day of Week & Time of the Day"
            subtitle=" "
            x=day_of_week xSort=day_number
            y=total
            value=sum_count
            legend=true
            valueLabels=true
            mobileValueLabels=true
            chartAreaHeight=50
        />    
        <Heatmap 
            data={day_time} 
            subtitle="24-Hour Format"
            x=hour_number xSort=hour_number
            y=day_of_week ySort=day_number
            value=sum_count
            legend=true
            filter=true
            mobileValueLabels=true
        />
        <Heatmap 
            data={time} 
            subtitle="24-Hour Format"
            x=hour_number xSort=hour_number
            y=Total
            value=sum_count
            legend=true
            filter=true
            chartAreaHeight=50
            mobileValueLabels=true
        />
    </Group>
</Grid>

<DataTable data={intersections_table} subtitle="Select an intersection or road from the resulting search to zoom into the hexagon that contains it." rowShading=true rows=5 link=link downloadable=false search=true>
    <Column id=GRID_ID title="Hexagon ID"/>
    <Column id=INTERSECTIONNAMES title="Intersections / Roads in Hexagon" wrap="true"/>
</DataTable>

<Details title="Having trouble with the search? Tap here for solutions.">

### Tips:
- For numbered streets, keep the ordinal attached directly to the number without spaces (e.g., "14TH ST NW" is correct, while "14 TH ST NW" is not).
- Always include the road type after the name or number, followed by the quadrant (e.g., "PENNSYLVANIA AVE NW").
- Don’t use "and" for intersections; always use "&" (e.g., "14TH ST NW & PENNSYLVANIA AVE NW").

</Details>