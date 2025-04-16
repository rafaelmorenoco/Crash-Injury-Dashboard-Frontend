---
title: Traffic Fatalities
queries:
   - fatality: fatality.sql
sidebar_position: 1
---

<Details title="About this dashboard">

    This dashboard shows traffic fatalities in the District of Columbia and can be filtered from 20__-present. Following a fatal crash, the DDOT team visits the site and, in coordination with The Metropolitan Police Department's (MPD) Major Crash Investigation Unit, determines if there are any short-term measures that DDOT can install to improve safety for all roadway users. Starting in 2021, site visit findings and follow-up can be found in the docked window on the right for each fatality.
    
    Adjust the Mode, Date, and Ward filters to refine the results in the map. All charts will update to reflect the fatalities affected by the filters. 
    
    Data are updated twice: first, as soon as DDOT receives a fatality memo from the Metropolitan Police Department (MPD) and second, after a crash site visit has been completed.

</Details>

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

```sql yoy_text_fatal
    WITH date_params AS (
        SELECT 
            date_trunc('year', current_date) AS current_year_start,
            current_date AS current_year_end,
            date_trunc('year', current_date - interval '1 year') AS prior_year_start,
            current_date - interval '1 year' AS prior_year_end,
            extract(year FROM current_date) AS current_year,
            extract(year FROM current_date - interval '1 year') AS year_prior
    ),
    yearly_counts AS (
        SELECT
            SUM(CASE WHEN cr.REPORTDATE >= dp.current_year_start 
                    AND cr.REPORTDATE <= dp.current_year_end THEN cr.COUNT ELSE 0 END) AS current_year_sum,
            SUM(CASE WHEN cr.REPORTDATE >= dp.prior_year_start 
                    AND cr.REPORTDATE <= dp.prior_year_end THEN cr.COUNT ELSE 0 END) AS prior_year_sum
        FROM 
            crashes.crashes AS cr
            CROSS JOIN date_params dp
        WHERE 
            cr.SEVERITY = 'Fatal'
            AND cr.REPORTDATE >= dp.prior_year_start
            AND cr.REPORTDATE <= dp.current_year_end
    )
    SELECT 
        'Fatal' AS severity,
        yc.current_year_sum,
        yc.prior_year_sum,
        ABS(yc.current_year_sum - yc.prior_year_sum) AS difference,
        CASE 
            WHEN yc.prior_year_sum != 0 
            THEN NULLIF((yc.current_year_sum - yc.prior_year_sum)::numeric / yc.prior_year_sum, 0)
            ELSE NULL 
        END AS percentage_change,
        CASE 
            WHEN (yc.current_year_sum - yc.prior_year_sum) > 0 THEN 'an increase of'
            WHEN (yc.current_year_sum - yc.prior_year_sum) < 0 THEN 'a decrease of'
            ELSE NULL 
        END AS percentage_change_text,
        CASE 
            WHEN (yc.current_year_sum - yc.prior_year_sum) > 0 THEN 'more'
            WHEN (yc.current_year_sum - yc.prior_year_sum) < 0 THEN 'fewer'
            ELSE 'no change'
        END AS difference_text,
        dp.current_year,
        dp.year_prior,
        CASE WHEN yc.current_year_sum = 1 THEN 'has' ELSE 'have' END AS has_have,
        CASE WHEN yc.current_year_sum = 1 THEN 'fatality' ELSE 'fatalities' END AS fatality
    FROM 
        yearly_counts yc
        CROSS JOIN date_params dp;
```

```sql inc_map
  select
      REPORTDATE,
      LATITUDE,
      LONGITUDE,
      MODE,
      SEVERITY,
      ADDRESS,
      '/fatalities/' || OBJECTID AS link
  from crashes.crashes
  where MODE IN ${inputs.multi_mode_dd.value}
  and SEVERITY = 'Fatal'
  and REPORTDATE between '${inputs.date_range.start}' and '${inputs.date_range.end}'
  group by all
```

```sql mode_selection
    SELECT
        STRING_AGG(DISTINCT MODE, ', ' ORDER BY MODE ASC) AS MODE_SELECTION
    FROM
        crashes.crashes
    WHERE
        MODE IN ${inputs.multi_mode_dd.value};
```

<Grid cols=2>
    <Group>
        As of <Value data={last_record} column="latest_record"/> there <Value data={yoy_text_fatal} column="has_have"/> been <Value data={yoy_text_fatal} column="current_year_sum" agg=sum/> <Value data={yoy_text_fatal} column="fatality"/> for all modes in <Value data={yoy_text_fatal} column="current_year" fmt='####","'/>   <Value data={yoy_text_fatal} column="difference" agg=sum fmt='####' /> <Value data={yoy_text_fatal} column="difference_text"/> (<Delta data={yoy_text_fatal} column="percentage_change" fmt="+0%;-0%;0%" downIsGood=True neutralMin=-0.00 neutralMax=0.00/>) compared to the same period in <Value data={yoy_text_fatal} column="year_prior" fmt="####."/>
    </Group>
    <Group>
        <DateRange
            start='2018-01-01'
            title="Select Time Period"
            name=date_range
            presetRanges={['Last 7 Days','Last 30 Days','Last 90 Days','Last 3 Months','Last 6 Months','Year to Today','Last Year','All Time']}
            defaultValue={'Year to Today'}
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
    </Group>
</Grid>

<Alert status="info">
The slection for <b>Mode</b> is: <b><Value data={mode_selection} column="MODE_SELECTION"/></b> <Info description="*Fatal only." color="primary" />
</Alert>

<Grid cols=2>
    <Group>
        <Note>
            Use Mode and Time Period filters above the table to further refine the data.
        </Note>
        <BaseMap
            height=470
            startingZoom=11
        >
            <Points data={inc_map} lat=LATITUDE long=LONGITUDE pointName=MODE value=SEVERITY colorPalette={['#ff5a53']} link=link ignoreZoom=true
            tooltip={[
                {id:'MODE', showColumnName:false, fmt:'id', valueClass:'text-l font-semibold'},
                {id:'REPORTDATE', showColumnName:false, fmt:'mm/dd/yy hh:mm'},
                {id:'ADDRESS', showColumnName:false, fmt:'id'}
            ]}
            />
            <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00/ 
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
        <Note class='text-sm'>
            Select a fatality in the table or map to see more details.
        </Note>
        <DataTable data={inc_map} link=link wrapTitles=true rowShading=true rows=8>
            <Column id=REPORTDATE title="Date" fmt='mm/dd/yy hh:mm' wrap=true/>
            <Column id=MODE title="Mode" wrap=true/>
            <Column id=ADDRESS wrap=true/>
        </DataTable>
    </Group>
</Grid>    