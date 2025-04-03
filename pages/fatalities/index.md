---
title: Traffic Fatalities
queries:
   - fatality: fatality.sql
---

As of yesterday <Value data={yesterday} column="Yesterday"/> there <Value data={yoy_text_fatal} column="has_have"/> been <Value data={yoy_text_fatal} column="current_year_sum" agg=sum/> <Value data={yoy_text_fatal} column="fatality"/> for all modes in <Value data={yoy_text_fatal} column="current_year" fmt='####","'/>   <Value data={yoy_text_fatal} column="difference" agg=sum fmt='####' /> <Value data={yoy_text_fatal} column="difference_text"/> (<Delta data={yoy_text_fatal} column="percentage_change" fmt="+0%;-0%;0%" downIsGood=True neutralMin=-0.00 neutralMax=0.00/>) compared to the same period in <Value data={yoy_text_fatal} column="year_prior" fmt="####."/>

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
from dbricks.crashes
group by 1
```

```sql yesterday
    SELECT 
        '(' || 
        RIGHT('0' || EXTRACT(MONTH FROM CURRENT_DATE - INTERVAL '1 DAY'), 2) || '/' ||
        RIGHT('0' || EXTRACT(DAY FROM CURRENT_DATE - INTERVAL '1 DAY'), 2) || '/' ||
        RIGHT(EXTRACT(YEAR FROM CURRENT_DATE - INTERVAL '1 DAY')::text, 2) || 
        '),' AS Yesterday
```

```sql unique_hin
select 
    GIS_ID,
    ROUTENAME
from dbricks.hin
group by all
```

```sql yoy_text_fatal
    WITH modes_and_severities AS (
        SELECT DISTINCT 
            SEVERITY 
        FROM 
            dbricks.crashes
    ), 
    current_year AS (
        SELECT 
            SEVERITY, 
            sum(COUNT) as sum_count,
            extract(year from current_date) as current_year
        FROM 
            dbricks.crashes 
        WHERE 
            SEVERITY = 'Fatal'
            AND REPORTDATE >= date_trunc('year', current_date)
        GROUP BY 
            SEVERITY
    ), 
    prior_year AS (
        SELECT 
            SEVERITY, 
            sum(COUNT) as sum_count,
            extract(year from current_date - interval '1 year') as year_prior
        FROM 
            dbricks.crashes 
        WHERE 
            SEVERITY = 'Fatal'
            AND REPORTDATE >= (date_trunc('year', current_date) - interval '1 year')
            AND REPORTDATE < (current_date - interval '1 year')
        GROUP BY 
            SEVERITY
    )
    SELECT 
        mas.SEVERITY, 
        COALESCE(cy.sum_count, 0) as current_year_sum, 
        COALESCE(py.sum_count, 0) as prior_year_sum, 
        COALESCE(ABS(COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)), 0) AS difference,
        CASE 
            WHEN COALESCE(py.sum_count, 0) != 0 AND COALESCE(cy.sum_count, 0) != 0 THEN 
                CASE 
                    WHEN ((COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)) / COALESCE(py.sum_count, 0)) = 0 THEN NULL
                    ELSE ((COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)) / COALESCE(py.sum_count, 0))
                END
            ELSE NULL 
        END as percentage_change,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) > 0 THEN 'an increase of'
            WHEN COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) < 0 THEN 'a decrease of'
            ELSE NULL 
        END as percentage_change_text,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) > 0 THEN 'more'
            WHEN COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) < 0 THEN 'fewer'
            ELSE 'no change' 
        END as difference_text,
        extract(year from current_date) as current_year,
        COALESCE(py.year_prior, extract(year from current_date - interval '1 year')) as year_prior,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) = 1 THEN 'has' 
            ELSE 'have' 
        END as has_have,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) = 1 THEN 'fatality' 
            ELSE 'fatalities' 
        END as fatality
    FROM 
        modes_and_severities mas
    LEFT JOIN 
        current_year cy 
    ON 
        mas.SEVERITY = cy.SEVERITY
    LEFT JOIN 
        prior_year py 
    ON 
        mas.SEVERITY = py.SEVERITY
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
  from dbricks.crashes
  where MODE IN ${inputs.multi_mode_dd.value}
  and SEVERITY = 'Fatal'
  and REPORTDATE between '${inputs.date_range.start}' and '${inputs.date_range.end}'
  group by all
```

<DateRange
  start='2018-01-01'
  title="Select Time Period"
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
    description="*Only fatal"
/>

<Note class='text-sm'>
    Select a fatality in the table or map to see more details.
</Note>

<DataTable data={inc_map} link=link wrapTitles=true rowShading=true>
    <Column id=REPORTDATE title="Date" fmt='mm/dd/yy hh:mm' wrap=true/>
    <Column id=MODE title="Mode" wrap=true/>
    <Column id=ADDRESS wrap=true/>
</DataTable>


<Note>
    Use Mode and Time Period filters above the table to further refine the data.
</Note>
<BaseMap
    height=650
    startingZoom=12
>
    <Points data={inc_map} lat=LATITUDE long=LONGITUDE pointName=MODE value=SEVERITY colorPalette={['#d62828']} link=link
    tooltip={[
        {id:'MODE', showColumnName:false, fmt:'id', valueClass:'text-l font-semibold'},
        {id:'REPORTDATE', showColumnName:false, fmt:'mm/dd/yy hh:mm'},
        {id:'ADDRESS', showColumnName:false, fmt:'id'}
    ]}
    />
    <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00/ ignoreZoom=true
    tooltip={[
        {id: 'ROUTENAME'}
    ]}
    />
</BaseMap>
<Note>
    The purple lines represent DC's High Injury Network
</Note>