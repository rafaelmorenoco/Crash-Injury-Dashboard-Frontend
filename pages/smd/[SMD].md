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

```sql table_query
WITH 
    report_date_range AS (
        SELECT
            CASE 
                WHEN '${inputs.date_range.end}'::DATE >= (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes) THEN 
                    (SELECT MAX(REPORTDATE) FROM crashes.crashes)
                ELSE 
                    '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
            END AS end_date,
            '${inputs.date_range.start}'::DATE AS start_date
    )
SELECT
    REPORTDATE,
    SEVERITY,
    MODE,
    ADDRESS,
    sum(COUNT) as Count
FROM crashes.crashes
WHERE MODE IN ${inputs.multi_mode_dd.value}
AND SMD = '${params.SMD}'
AND SEVERITY IN ${inputs.multi_severity.value}
AND REPORTDATE BETWEEN (SELECT start_date FROM report_date_range) AND (SELECT end_date FROM report_date_range)
GROUP BY all
```

```sql incidents
WITH 
    report_date_range AS (
        SELECT
            CASE 
                WHEN '${inputs.date_range.end}'::DATE >= (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes)::DATE THEN 
                    (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE + INTERVAL '1 day'
                ELSE 
                    '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
            END AS end_date,
            '${inputs.date_range.start}'::DATE AS start_date
    )
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
  AND REPORTDATE BETWEEN (SELECT start_date FROM report_date_range) 
                      AND (SELECT end_date FROM report_date_range)
GROUP BY all;
```

```sql anc_map
WITH 
    report_date_range AS (
        SELECT
            CASE 
                WHEN '${inputs.date_range.end}'::DATE >= (SELECT CAST(MAX(REPORTDATE) AS DATE) FROM crashes.crashes)::DATE THEN 
                    (SELECT MAX(REPORTDATE) FROM crashes.crashes)::DATE + INTERVAL '1 day'
                ELSE 
                    '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
            END AS end_date,
            '${inputs.date_range.start}'::DATE AS start_date
    )
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
        AND crashes.REPORTDATE BETWEEN (SELECT start_date FROM report_date_range) AND (SELECT end_date FROM report_date_range)
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
  start="2018-01-01"
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

<Alert status="info">
The slection for <b>Severity</b> is: <b><Value data={mode_severity_selection} column="SEVERITY_SELECTION"/></b>. The slection for <b>Road User</b> is: <b><Value data={mode_severity_selection} column="MODE_SELECTION"/></b> <Info description="*Fatal only." color="primary" />
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
          <Column id=SEVERITY totalAgg="-"/>
          <Column id=MODE totalAgg='{inputs.multi_mode}'/>
          <Column id=ADDRESS title='Approx Address' wrap=true totalAgg="-"/>
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

<Note>
    The latest crash record in the dataset is from <Value data={last_record} column="latest_record"/> and the data was last updated on <Value data={last_record} column="latest_update"/> hrs. This lag factors into prior period comparisons. The maximum comparison period is 5 years.
</Note>