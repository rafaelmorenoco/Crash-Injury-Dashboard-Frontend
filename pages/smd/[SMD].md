---
queries:
   - smd_link: smd_link.sql
---

# SMD {params.SMD}

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

```sql unique_anc
    SELECT 
        CASE 
            WHEN SMD LIKE '3-4G%' THEN '3-4G'
            ELSE SUBSTRING(SMD, 1, 2)
        END AS ANC
    FROM smd.smd_2023
    WHERE SMD = '${params.SMD}'
    GROUP BY 1;
```

```sql unique_hin
select 
    GIS_ID,
    ROUTENAME
from hin.hin
group by all
```

```sql unique_smd
select 
    SMD
from smd.smd_2023
where SMD = '${params.SMD}'
group by 1
```

```sql table_query
  select
      REPORTDATE,
      SEVERITY,
      MODE,
      sum(COUNT) as Count
  from crashes.crashes
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
  from crashes.crashes
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
  from crashes.crashes
  where MODE IN ${inputs.multi_mode_dd.value}
  and SEVERITY IN ${inputs.multi_severity.value}
  and REPORTDATE between '${inputs.date_range.start}' and '${inputs.date_range.end}'
  and SMD is not null
  group by all
```

```sql anc_map
    SELECT 
        smd_2023.SMD,
        '/smd/' || smd_2023.SMD AS link,
        COALESCE(subquery.Injuries, 0) AS Injuries
    FROM 
        smd.smd_2023 AS smd_2023
    LEFT JOIN (
        SELECT
            crashes.SMD,
            SUM(COUNT) AS Injuries
        FROM 
            crashes.crashes AS crashes
        WHERE 
            ANC = (SELECT 
                CASE 
                    WHEN smd_2023.SMD LIKE '3-4G%' THEN '3-4G'
                    ELSE SUBSTRING(smd_2023.SMD, 1, 2)
                END AS ANC
            FROM smd.smd_2023 AS smd_2023
            WHERE smd_2023.SMD = '${params.SMD}'
            GROUP BY 1)
            AND crashes.MODE IN ${inputs.multi_mode_dd.value}
            AND crashes.SEVERITY IN ${inputs.multi_severity.value}
            AND crashes.REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
            AND crashes.SMD IS NOT NULL
        GROUP BY 
            crashes.SMD
    ) AS subquery
    ON 
        smd_2023.SMD = subquery.SMD
    JOIN (
        SELECT DISTINCT crashes.SMD
        FROM crashes.crashes AS crashes
        WHERE ANC = (SELECT 
            CASE 
                WHEN smd_2023.SMD LIKE '3-4G%' THEN '3-4G'
                ELSE SUBSTRING(smd_2023.SMD, 1, 2)
            END AS ANC
        FROM smd.smd_2023 AS smd_2023
        WHERE smd_2023.SMD = '${params.SMD}'
        GROUP BY 1)
    ) AS smd_anc
    ON 
        smd_2023.SMD = smd_anc.SMD
    ORDER BY 
        smd_2023.SMD;
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
  presetRanges={['Month to Today','Last Month','Year to Today','Last Year']}
  defaultValue={'Year to Today'}
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
The slection for <b>Severity</b> is: <b><Value data={mode_severity_selection} column="SEVERITY_SELECTION"/></b>. The slection for <b>Mode</b> is: <b><Value data={mode_severity_selection} column="MODE_SELECTION"/></b> <Info description="*Fatal only." color="primary" />
</Alert>

### Selected SMD

<Grid cols=2>
    <Group>
        <Note>
        Each point on the map represents an injury. Injury incidents can overlap in the same spot.
        </Note>
        <BaseMap
          height=500
          startingZoom=15
        >
          <Points data={incidents} lat=LATITUDE long=LONGITUDE value=SEVERITY pointName=MODE opacity=1 colorPalette={['#ffdf00','#ff9412','#ff5a53']} ignoreZoom=true
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
    </Group>    
    <Group>
        <DataTable data={table_query} sort="REPORTDATE desc" totalRow=true rows=5 subtitle='Injury Table' rowShading=true>
          <Column id=REPORTDATE title='Date' fmt='mm/dd/yy hh:mm' totalAgg="Total"/>
          <Column id=SEVERITY totalAgg="-"/>
          <Column id=MODE totalAgg='{inputs.multi_mode}'/>
          <Column id=Count totalAgg=sum/>
        </DataTable>
        <Alert status="info">
            To navigate to another SMD within ANC <Value data={unique_anc} column="ANC"/> go to the "Selected ANC" section bellow.
        </Alert>
    </Group>
</Grid>

#### Selected ANC
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