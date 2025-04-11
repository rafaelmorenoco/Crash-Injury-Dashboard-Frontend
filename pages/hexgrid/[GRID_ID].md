---
queries:
   - hex: hex.sql
---

# {params.GRID_ID}

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

```sql table_query
  select
      REPORTDATE,
      SEVERITY,
      MODE,
      sum(COUNT) as Count
  from crashes.crashes
  where MODE IN ${inputs.multi_mode_dd.value}
  and GRID_ID = '${params.GRID_ID}'
  and SEVERITY IN ${inputs.multi_severity.value}
  and REPORTDATE between '${inputs.date_range.start}' and '${inputs.date_range.end}'
  group by all
```

```sql incidents
  select
      --GRID_ID,
      MODE,
      SEVERITY,
      LATITUDE,
      LONGITUDE
  from crashes.crashes
  where MODE IN ${inputs.multi_mode_dd.value}
  --and GRID_ID = '${params.GRID_ID}'
  and SEVERITY IN ${inputs.multi_severity.value}
  and REPORTDATE between '${inputs.date_range.start}' and '${inputs.date_range.end}'
  group by all
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

<!---
sql hex_map
  select
      GRID_ID,
      sum(COUNT) as Injuries,
      '/hexgrid/' || GRID_ID as link_map
  from crashes.crashes
  where MODE IN ${inputs.multi_mode_dd.value}
  and SEVERITY IN ${inputs.multi_severity.value}
  and REPORTDATE between '${inputs.date_range.start}' and '${inputs.date_range.end}'
  and GRID_ID is not null
  group by all
-->

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

<Alert status="info">
The selected transportation <Value data={modes_selected} column="PLURAL_SINGULAR"/> <Value data={modes_selected} column="MODE_SELECTED"/>
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
          <Points data={incidents} lat=LATITUDE long=LONGITUDE value=SEVERITY pointName=MODE opacity=1 colorPalette={['#ffdf00','#ff9412','#ff5a53']} ignoreZoom=true/>
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
        <DataTable data={table_query} sort="REPORTDATE desc" totalRow=true rows=5 subtitle='Injury Table' rowShading=true>
          <Column id=REPORTDATE title='Date' fmt='mm/dd/yy hh:mm' totalAgg="Total"/>
          <Column id=SEVERITY totalAgg="-"/>
          <Column id=MODE totalAgg='{inputs.multi_mode}'/>
          <Column id=Count totalAgg=sum/>
        </DataTable>
        <Alert status="info">
            To navigate to another hexagon, use the intersection search function below, or go back to: <a href="https://crash-injury-dashboard.evidence.app/hexgrid/">Injuries Heatmap</a>.
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

<Details title="Having trouble with the search? Tap here for solutions.">

### Tips:
- For numbered streets, keep the ordinal attached directly to the number without spaces (e.g., "14TH ST NW" is correct, while "14 TH ST NW" is not).
- Always include the road type after the name or number, followed by the quadrant (e.g., "PENNSYLVANIA AVE NW").
- Don’t use "and" for intersections; always use "&" (e.g., "14TH ST NW & PENNSYLVANIA AVE NW").
- If you don’t see the intersection listed here, try reversing the order (e.g., change "PENNSYLVANIA AVE NW & 14TH ST NW" to "14TH ST NW & PENNSYLVANIA AVE NW").

</Details>