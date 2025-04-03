---
queries:
   - smd_link: smd_link.sql
---

# SMD {params.SMD}

```sql unique_mode
select 
    MODE
from dbricks.crashes
group by 1
```

```sql unique_severity
select 
    SEVERITY
from dbricks.crashes
group by 1
```

```sql unique_anc
    SELECT 
        CASE 
            WHEN SMD LIKE '3-4G%' THEN '3-4G'
            ELSE SUBSTRING(SMD, 1, 2)
        END AS ANC
    FROM dbricks.smd
    WHERE SMD = '${params.SMD}'
    GROUP BY 1;
```

```sql unique_hin
select 
    GIS_ID,
    ROUTENAME
from dbricks.hin
group by all
```

```sql unique_smd
select 
    SMD
from dbricks.smd
where SMD = '${params.SMD}'
group by 1
```

```sql table_query
  select
      REPORTDATE,
      SEVERITY,
      MODE,
      sum(COUNT) as Count
  from dbricks.crashes
  where MODE IN ${inputs.multi_mode_dd.value}
  and SMD = '${params.SMD}'
  and SEVERITY IN ${inputs.multi_severity.value}
  and REPORTDATE between '${inputs.date_range.start}' and '${inputs.date_range.end}'
  group by all
```

```sql incidents
  select
      --SMD,
      MODE,
      SEVERITY,
      LATITUDE,
      LONGITUDE,
      REPORTDATE,
      ADDRESS
  from dbricks.crashes
  where MODE IN ${inputs.multi_mode_dd.value}
  --and SMD = '${params.SMD}'
  and SEVERITY IN ${inputs.multi_severity.value}
  and REPORTDATE between '${inputs.date_range.start}' and '${inputs.date_range.end}'
  group by all
```

```sql smd_map
  select
      SMD,
      sum(COUNT) as Incident_Per_Hex,
      '/smd/' || SMD as link
  from dbricks.crashes
  where MODE IN ${inputs.multi_mode_dd.value}
  and SEVERITY IN ${inputs.multi_severity.value}
  and REPORTDATE between '${inputs.date_range.start}' and '${inputs.date_range.end}'
  and SMD is not null
  group by all
```

```sql anc_map
SELECT 
    smd.SMD,
    '/smd/' || smd.SMD AS link,
    COALESCE(subquery.Injuries, 0) AS Injuries
FROM 
    dbricks.smd
LEFT JOIN (
    SELECT
        SMD,
        SUM(COUNT) AS Injuries
    FROM 
        dbricks.crashes
    WHERE 
        ANC = (SELECT 
            CASE 
                WHEN SMD LIKE '3-4G%' THEN '3-4G'
                ELSE SUBSTRING(SMD, 1, 2)
            END AS ANC
        FROM dbricks.smd
        WHERE SMD = '${params.SMD}'
        GROUP BY 1)
        AND MODE IN ${inputs.multi_mode_dd.value}
        AND SEVERITY IN ${inputs.multi_severity.value}
        AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
        AND SMD IS NOT NULL
    GROUP BY 
        SMD
) AS subquery
ON 
    smd.SMD = subquery.SMD
JOIN (
    SELECT DISTINCT SMD
    FROM dbricks.crashes
    WHERE ANC = (SELECT 
        CASE 
            WHEN SMD LIKE '3-4G%' THEN '3-4G'
            ELSE SUBSTRING(SMD, 1, 2)
        END AS ANC
    FROM dbricks.smd
    WHERE SMD = '${params.SMD}'
    GROUP BY 1)
) AS smd_anc
ON 
    smd.SMD = smd_anc.SMD
ORDER BY 
    smd.SMD;
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

<Tabs fullWidth=true>
    <Tab label="Selected SMD">
        <Note>
            To navigate to another SMD within ANC <Value data={unique_anc} column="ANC"/> go to the "Selected ANC" tab above the table.
        </Note>
        <DataTable data={table_query} sort="REPORTDATE desc" totalRow=true rows=5 subtitle='Injury Table' rowShading=true>
          <Column id=REPORTDATE title='Date' fmt='mm/dd/yy hh:mm' totalAgg="Total"/>
          <Column id=SEVERITY totalAgg="-"/>
          <Column id=MODE totalAgg='{inputs.multi_mode}'/>
          <Column id=Count totalAgg=sum/>
        </DataTable>
        <Note>
        Each point on the map represents an injury. Injury incidents can overlap in the same spot.
        </Note>
        <BaseMap
          height=500
          startingZoom=15
        >
          <Points data={incidents} lat=LATITUDE long=LONGITUDE value=SEVERITY pointName=MODE opacity=1 colorPalette={['#fcbf49','#f77f00','#d62828']} ignoreZoom=true
            tooltip={[
                {id:'MODE', showColumnName:false, fmt:'id', valueClass:'text-l font-semibold'},
                {id:'REPORTDATE', showColumnName:false, fmt:'mm/dd/yy hh:mm'},
                {id:'ADDRESS', showColumnName:false, fmt:'id'}
            ]}/>
          <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00/ borderWidth=1.5 ignoreZoom=true
          tooltip={[
                {id: 'ROUTENAME'}
            ]}
          />
          <Areas data={unique_smd} geoJsonUrl='/smd_2023.geojson' geoId=SMD areaCol=SMD min=0 borderColor=#000000 color=#1C00ff00 borderWidth=1.75/>
        </BaseMap>
        <Note>
        The purple lines represent DC's High Injury Network
        </Note>
    </Tab>
    <Tab label="Selected ANC">
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
        <Areas data={anc_map} height=650 startingZoom=13 geoJsonUrl='/smd_2023.geojson' geoId=SMD areaCol=SMD value=Injuries min=0 borderWidth=1.5 borderColor='#A9A9A9' link=link
        />
        </BaseMap>
        <Note>
            The purple lines represent DC's High Injury Network
        </Note>
    </Tab>
</Tabs>