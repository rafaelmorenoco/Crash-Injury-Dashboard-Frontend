---
queries:
   - hex: hex.sql
   - last_record: last_record.sql
---

# Selected Hexagon

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
where GRID_ID = '${params.GRID_ID}'
group by 1
```

```sql unique_hin
select 
    GIS_ID,
    ROUTENAME
from hin.hin
group by all
```

```sql max_age
SELECT 
    MAX(AGE) AS unique_max_age
FROM crashes.crashes
WHERE SEVERITY IN ${inputs.multi_severity.value}
AND MODE IN ${inputs.multi_mode_dd.value}
AND REPORTDATE BETWEEN ('${inputs.date_range.start}'::DATE)
AND (('${inputs.date_range.end}'::DATE) + INTERVAL '1 day')
AND AGE < 110;
```

```sql table_query
SELECT
    REPORTDATE,
    MODE || '-' || SEVERITY AS mode_severity,
    ADDRESS,
    CASE
        WHEN CAST(AGE AS INTEGER) = 120 THEN '-'
        ELSE CAST(CAST(AGE AS INTEGER) AS VARCHAR)
    END AS Age,
    SUM(COUNT) AS Count
FROM crashes.crashes
WHERE MODE IN ${inputs.multi_mode_dd.value}
  AND GRID_ID = '${params.GRID_ID}'
  AND SEVERITY IN ${inputs.multi_severity.value}
  AND REPORTDATE BETWEEN ('${inputs.date_range.start}'::DATE)
      AND (('${inputs.date_range.end}'::DATE) + INTERVAL '1 day')
  AND AGE BETWEEN '${inputs.min_age}' AND '${inputs.max_age}'
GROUP BY
    REPORTDATE,
    MODE,
    SEVERITY,
    ADDRESS,
    AGE;
```

```sql incidents
SELECT
    MODE,
    SEVERITY,
    ADDRESS,
    REPORTDATE,
    LATITUDE,
    LONGITUDE,
    SUM(COUNT) AS Count
FROM crashes.crashes
WHERE MODE IN ${inputs.multi_mode_dd.value}
  AND SEVERITY IN ${inputs.multi_severity.value}
  AND REPORTDATE BETWEEN ('${inputs.date_range.start}'::DATE) AND (('${inputs.date_range.end}'::DATE) + INTERVAL '1 day')
  AND AGE BETWEEN '${inputs.min_age}' AND '${inputs.max_age}'
GROUP BY
    MODE,
    SEVERITY,
    ADDRESS,
    REPORTDATE,
    LATITUDE,
    LONGITUDE;
```

```sql intersection_list
SELECT INTERSECTIONNAME
FROM intersections.intersections
WHERE GRID_ID = '${params.GRID_ID}'

UNION ALL

SELECT 'There are no intersections within the hexagon'
WHERE NOT EXISTS (
    SELECT 1 
    FROM intersections.intersections 
    WHERE GRID_ID = '${params.GRID_ID}'
);
```

```sql intersections_table
SELECT
    INTERSECTIONNAME,
    '/hexgrid/' || GRID_ID AS link
FROM
    intersections.intersections
WHERE
    INTERSECTIONNAME ILIKE '%' || '${inputs.intersection_search}' || '%'
LIMIT 5;
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

<Grid cols=2>
    <Group>
        <DataTable data={intersection_list}>
                <Column id=INTERSECTIONNAME title='Intersections Within {params.GRID_ID}' wrap=true/>
        </DataTable>
    </Group>
    <Group>
        <DateRange
        start="2017-01-01"
        end={
            (last_record && last_record[0] && last_record[0].end_date)
            ? `${last_record[0].end_date}`
            : (() => {
                const twoDaysAgo = new Date(new Date().setDate(new Date().getDate() - 2));
                return new Intl.DateTimeFormat('en-CA', {
                    timeZone: 'America/New_York'
                }).format(twoDaysAgo);
                })()
        }
        title="Select Time Period"
        name="date_range"
        presetRanges={['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'Last 6 Months', 'Last 12 Months', 'Month to Today', 'Last Month', 'Year to Today', 'Last Year', 'All Time']}
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
        <TextInput
            name="min_age" 
            title="Enter Min Age"
            defaultValue="0"
        />
        <TextInput
            name="max_age"
            title="Enter Max Age**"
            defaultValue="120"
            description="**For an accurate age count, enter a maximum age below 120, as 120 serves as a placeholder for missing age values in the records. The actual maximum age for the current selection of filters is {max_age[0].unique_max_age}."
        />
    </Group>
</Grid>

<Alert status="info">
The selection for <b>Severity</b> is: <b><Value data={mode_severity_selection} column="SEVERITY_SELECTION"/></b>. The selection for <b>Road User</b> is: <b><Value data={mode_severity_selection} column="MODE_SELECTION"/></b> <Info description="*Fatal only." color="primary" />
</Alert>

### Selected Hexagon

<Grid cols=2>
    <Group>
        <Note>
        Each point on the map represents an injury. Injury incidents can overlap in the same spot.
        </Note>
        <BaseMap
          height=400
          startingZoom=17
        >
          <Points data={incidents} lat=LATITUDE long=LONGITUDE value=SEVERITY pointName=MODE opacity=1 colorPalette={['#ffdf00','#ff9412','#ff5a53']} ignoreZoom=true             
          tooltip={[
                {id:'MODE', showColumnName:false, fmt:'id', valueClass:'text-l font-semibold'},
                {id:'REPORTDATE', showColumnName:false, fmt:'mm/dd/yy hh:mm'},
                {id:'ADDRESS', showColumnName:false, fmt:'id'},
                {id:'Count'}
            ]}/>
          <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00/ borderWidth=1.5 ignoreZoom=true
          tooltip={[
                {id: 'ROUTENAME'}
            ]}
          />
          <Areas data={unique_hex} geoJsonUrl='/crash-hexgrid.geojson' geoId=GRID_ID areaCol=GRID_ID min=0 borderColor=#000000 color=#1C00ff00/>
        </BaseMap>
        <Note>
        The purple lines represent DC's High Injury Network
        </Note>
    </Group>    
    <Group>
        <DataTable data={table_query} sort="REPORTDATE desc" totalRow=true rows=5 title='Injury Table' rowShading=true wrapTitles=true>
          <Column id=REPORTDATE title='Date' fmt='mm/dd/yy hh:mm' totalAgg="Total" wrap=true description="24-Hour Format"/>
          <Column id=mode_severity title='Road User - Severity' totalAgg="-" wrap=true/>
          <Column id=Age totalAgg="-"/>
          <Column id=ADDRESS title='Apporx Address' wrap=true/>
          <Column id=Count totalAgg=sum/>
        </DataTable>
        <Alert status="info">
            To navigate to another hexagon, use the intersection search function below, or go back to: <b><a href="https://crash-injury-dashboard.evidence.app/hexgrid/">Injuries Heatmap</a></b>.
        </Alert>
        <TextInput
            name=intersection_search
            title="Intersection Search"
            description="Search for an intersection within a hexagon"
            placeholder="E.g. 14TH ST NW & PENNSYLVANIA AVE NW"
            defaultValue="14TH ST NW"
        />
        <DataTable data={intersections_table} subtitle="Select an intersection from the resulting search to zoom into the hexagon that contains it." rowShading=true rows=5 link=link downloadable=false>
                    <Column id=INTERSECTIONNAME title="Intersection Match:"/>
        </DataTable>
    </Group>
</Grid>

<Details title="Having trouble with the search? Tap/click here for solutions.">

### Tips:
- For numbered streets, keep the ordinal attached directly to the number without spaces (e.g., "14TH ST NW" is correct, while "14 TH ST NW" is not).
- Always include the road type after the name or number, followed by the quadrant (e.g., "PENNSYLVANIA AVE NW").
- Don’t use "and" for intersections; always use "&" (e.g., "14TH ST NW & PENNSYLVANIA AVE NW").
- If you don’t see the intersection listed here, try reversing the order (e.g., change "PENNSYLVANIA AVE NW & 14TH ST NW" to "14TH ST NW & PENNSYLVANIA AVE NW").

</Details>

<Note>
    The latest crash record in the dataset is from <Value data={last_record} column="latest_record"/> and the data was last updated on <Value data={last_record} column="latest_update"/> hrs.
</Note>