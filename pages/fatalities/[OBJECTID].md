---
queries:
   - fatality: fatality.sql
---

# <Value data={Tittle} column=ADDRESS/> - <Value data={Tittle} column=Date/>

```sql fatality_with_link
select *, '/fatalities/' || OBJECTID as link
from ${fatality}
```

```sql unique_mode
select 
    MODE
from dbricks.crashes
group by 1
```

```sql unique_hin
select 
    GIS_ID,
    ROUTENAME
from dbricks.hin
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
    ADDRESS,
    CONCAT(
          LPAD(EXTRACT(MONTH FROM REPORTDATE)::TEXT, 2, '0'), '/', 
          LPAD(EXTRACT(DAY FROM REPORTDATE)::TEXT, 2, '0'), '/', 
          RIGHT(EXTRACT(YEAR FROM REPORTDATE)::TEXT, 2), ' ', 
          LPAD(EXTRACT(HOUR FROM REPORTDATE)::TEXT, 2, '0'), ':', 
          LPAD(EXTRACT(MINUTE FROM REPORTDATE)::TEXT, 2, '0')
    ) AS Date
  FROM dbricks.crashes
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
  FROM dbricks.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Mode', MODE::TEXT
  FROM dbricks.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'CCN', CCN::TEXT
  FROM dbricks.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Address', ADDRESS
  FROM dbricks.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Ward', WARD
  FROM dbricks.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Striking Vehicle', StrinkingVehicle
  FROM dbricks.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Second Striking Vehicle/Object', SecondStrikingVehicleObject
  FROM dbricks.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Site Visit Status', SiteVisitStatus
  FROM dbricks.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Factors Discussed at Site Visit', FactorsDiscussedAtSiteVisit
  FROM dbricks.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

UNION ALL

  SELECT 'Actions Planned and Completed', ActionsPlannedAndCompleted
  FROM dbricks.crashes
  WHERE MODE IN ${inputs.multi_mode_dd.value}
    AND OBJECTID = '${params.OBJECTID}'
    AND SEVERITY = 'Fatal'
    AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'

  UNION ALL

  SELECT 'Actions Under Consideration', ActionsUnderConsideration
  FROM dbricks.crashes
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
  from dbricks.crashes
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