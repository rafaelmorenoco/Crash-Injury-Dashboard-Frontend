---
queries:
   - fatality: fatality.sql
---

# <Value data={Tittle} column=Address/> - <Value data={Tittle} column=Date/>

```sql fatality_with_link
select *, '/fatalities/' || OBJECTID as link
from ${fatality}
```

```sql unique_mode
select 
    MODE
from crashes.crashes
group by 1
```

```sql unique_wards
select 
    NAME
from wards.Wards_from_2022
group by 1
```

```sql unique_hin
select 
    GIS_ID,
    ROUTENAME
from hin.High_Injury_Network
group by all
```

```sql columns
  SELECT column_name
  FROM information_schema.columns
  WHERE table_schema = 'crashes'
    AND table_name = 'crashes';
```

```sql Tittle
  SELECT 
    Address,
    CONCAT(
          LPAD(EXTRACT(MONTH FROM REPORTDATE)::TEXT, 2, '0'), '/', 
          LPAD(EXTRACT(DAY FROM REPORTDATE)::TEXT, 2, '0'), '/', 
          RIGHT(EXTRACT(YEAR FROM REPORTDATE)::TEXT, 2), ' ', 
          LPAD(EXTRACT(HOUR FROM REPORTDATE)::TEXT, 2, '0'), ':', 
          LPAD(EXTRACT(MINUTE FROM REPORTDATE)::TEXT, 2, '0')
    ) AS Date
  FROM crashes.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
```

```sql pivot_table
  SELECT 
    'Date' AS column_name, 
      CONCAT(
          LPAD(EXTRACT(MONTH FROM REPORTDATE)::TEXT, 2, '0'), '/', 
          LPAD(EXTRACT(DAY FROM REPORTDATE)::TEXT, 2, '0'), '/', 
          RIGHT(EXTRACT(YEAR FROM REPORTDATE)::TEXT, 2), ' ', 
          LPAD(EXTRACT(HOUR FROM REPORTDATE)::TEXT, 2, '0'), ':', 
          LPAD(EXTRACT(MINUTE FROM REPORTDATE)::TEXT, 2, '0')
      ) AS column_value
  FROM crashes.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Mode', MODE::TEXT
  FROM crashes.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'CCN', CCN::TEXT
  FROM crashes.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Address', Address
  FROM crashes.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Ward', WARD
  FROM crashes.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Striking Vehicle', StrinkingVehicle
  FROM crashes.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Second Striking Vehicle/Object', SecondStrikingVehicleObject
  FROM crashes.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Site Visit Status', SiteVisitStatus
  FROM crashes.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Factors Discussed at Site Visit', FactorsDiscussedAtSiteVisit
  FROM crashes.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

UNION ALL

  SELECT 'Actions Planned and Completed', ActionsPlannedAndCompleted
  FROM crashes.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Actions Under Consideration', ActionsUnderConsideration
  FROM crashes.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}';
```

```sql incidents
  select
      --OBJECTID,
      MODE,
      LATITUDE,
      LONGITUDE
  from crashes.crashes
  where MODE IN ${inputs.multi_mode_dd.value}
  and OBJECTID = '${params.OBJECTID}'
  and SEVERITY = 'Fatal'
  and REPORTDATE between '${inputs.date_range.start}' and '${inputs.date_range.end}'
  group by all
```

<DateRange
  start='2020-01-01'
  name=date_range
  presetRanges={['Last 7 Days','Last 30 Days','Last 90 Days','Last 3 Months','Last 6 Months','Year to Date','Last Year','All Time']}
  defaultValue={'Year to Date'}
/>

<Dropdown
    data={unique_mode} 
    name=multi_mode_dd
    value=MODE
    title="Select Mode"
    multiple=true
    selectAllByDefault=true
/>

<!---
<ButtonGroup
    data={unique_mode}
    name=multi_mode
    value=MODE
    defaultValue="Driver"
/>
-->
<Tabs fullWidth=true>
    <Tab label="Placeholder 1">
    <Grid cols=2>
        <BaseMap
          height=445
          startingZoom=17
          title="Fatality Location"
          >
          <Points data={incidents} lat=LATITUDE long=LONGITUDE value=MODE pointName=MODE colorPalette={['#d62828']}/>
          <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00/ ignoreZoom=true
          tooltip={[
            {id: 'ROUTENAME'}
          ]}
          />
        </BaseMap>
        <DataTable data={pivot_table} rows=all wrapTitles=true rowShading=true>
          <Column id=column_name title="Fatality Details" wrap=true/>
          <Column id=column_value title=" " wrap=true/>
        </DataTable>
        </Grid>
        <Note>
          The purple lines represent DC's High Injury Network
        </Note>
    </Tab>
    <Tab label="Placeholder 2">
 
    </Tab>
</Tabs>