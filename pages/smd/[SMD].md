---
queries:
   - smd_link: smd_link.sql
   - last_record: last_record.sql
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
  AND SMD = '${params.SMD}'
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
    LATITUDE,
    LONGITUDE,
    REPORTDATE,
    ADDRESS
FROM crashes.crashes
WHERE MODE IN ${inputs.multi_mode_dd.value}
AND SEVERITY IN ${inputs.multi_severity.value}
AND REPORTDATE BETWEEN ('${inputs.date_range.start}'::DATE)
AND (('${inputs.date_range.end}'::DATE)+ INTERVAL '1 day')
AND AGE BETWEEN '${inputs.min_age}' AND '${inputs.max_age}'
GROUP BY all;
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
  presetRanges={['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'Last 6 Months', 'Last 12 Months', 'Month to Today', 'Last Month', 'Year to Today', 'Last Year']}
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

<Alert status="info">
The selection for <b>Severity</b> is: <b><Value data={mode_severity_selection} column="SEVERITY_SELECTION"/></b>. The selection for <b>Road User</b> is: <b><Value data={mode_severity_selection} column="MODE_SELECTION"/></b> <Info description="*Fatal only." color="primary" />
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
        <DataTable data={table_query} sort="REPORTDATE desc" totalRow=true rows=5 subtitle='Injury Table' rowShading=true wrapTitles=true>
          <Column id=REPORTDATE title='Date' wrap=true fmt='mm/dd/yy hh:mm' totalAgg="Total"/>
          <Column id=mode_severity title='Road User - Severity' totalAgg="-" wrap=true/>
          <Column id=Age totalAgg="-"/>
          <Column id=ADDRESS title='Approx Address' wrap=true totalAgg="-"/>
          <Column id=Count totalAgg=sum/>
        </DataTable>
    </Group>
</Grid>

<Note>
    The latest crash record in the dataset is from <Value data={last_record} column="latest_record"/> and the data was last updated on <Value data={last_record} column="latest_update"/> hrs.
</Note>