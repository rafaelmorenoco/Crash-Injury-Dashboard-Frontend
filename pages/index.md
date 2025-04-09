---
title: DC Vision Zero Traffic Fatalities and Injury Crashes
---

As of yesterday <Value data={yesterday} column="Yesterday"/> there <Value data={yoy_text_fatal} column="has_have"/> been <Value data={yoy_text_fatal} column="current_year_sum" agg=sum/> <Value data={yoy_text_fatal} column="fatality"/> for all modes in <Value data={yoy_text_fatal} column="current_year" fmt='####","'/>   <Value data={yoy_text_fatal} column="difference" agg=sum fmt='####' /> <Value data={yoy_text_fatal} column="difference_text"/> (<Delta data={yoy_text_fatal} column="percentage_change" fmt="+0%;-0%;0%" downIsGood=True neutralMin=-0.00 neutralMax=0.00/>) compared to the same period in <Value data={yoy_text_fatal} column="year_prior" fmt="####."/>

<Details title="About this dashboard">

    The Fatal and Injury Crashes Dashboard can be used by the public to know more about injuries or fatalities product of a crash in the District of Columbia (DC).
    
    Adjust the Mode, Severity and Date filters to refine the results.

</Details>

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

```sql unique_wards
select 
    NAME,
    WARD_ID
from wards.wards_2022
group by all
```

```sql unique_hex
select 
    GRID_ID
from hexgrid.crash_hexgrid
group by 1
```

```sql unique_hin
select 
    GIS_ID,
    ROUTENAME
from hin.hin
group by all
```

```sql unique_anc
select 
    ANC
from anc.anc_2023
group by 1
```

```sql unique_smd
select 
    SMD
from smd.smd_2023
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

```sql barchart_mode
    WITH combinations AS (
        SELECT DISTINCT
            MODE,
            SEVERITY
        FROM crashes.crashes
    ),
    counts AS (
        SELECT
            MODE,
            SEVERITY,
            SUM(COUNT) AS sum_count
        FROM crashes.crashes
        WHERE SEVERITY IN ${inputs.multi_severity.value}
        AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
        GROUP BY MODE, SEVERITY
    )
    SELECT
        c.MODE,
        c.SEVERITY,
        COALESCE(cnt.sum_count, 0) AS sum_count
    FROM combinations c
    LEFT JOIN counts cnt
    ON c.MODE = cnt.MODE AND c.SEVERITY = cnt.SEVERITY;
```

```sql day_time
    WITH reference AS (
        SELECT
            dow.day_of_week,
            dow.day_number,
            hr.hour_number
        FROM 
            (VALUES 
                ('Sun', 0), ('Mon', 1), ('Tue', 2), 
                ('Wed', 3), ('Thu', 4), ('Fri', 5), ('Sat', 6)
            ) AS dow(day_of_week, day_number),
            GENERATE_SERIES(0, 23) AS hr(hour_number)
    ),
    count_data AS (
        SELECT
            CASE
                WHEN DATE_PART('dow', REPORTDATE) = 0 THEN 'Sun'
                WHEN DATE_PART('dow', REPORTDATE) = 1 THEN 'Mon'
                WHEN DATE_PART('dow', REPORTDATE) = 2 THEN 'Tue'
                WHEN DATE_PART('dow', REPORTDATE) = 3 THEN 'Wed'
                WHEN DATE_PART('dow', REPORTDATE) = 4 THEN 'Thu'
                WHEN DATE_PART('dow', REPORTDATE) = 5 THEN 'Fri'
                WHEN DATE_PART('dow', REPORTDATE) = 6 THEN 'Sat'
            END AS day_of_week,
            CASE
                WHEN DATE_PART('dow', REPORTDATE) = 1 THEN 0
                WHEN DATE_PART('dow', REPORTDATE) = 2 THEN 1
                WHEN DATE_PART('dow', REPORTDATE) = 3 THEN 2
                WHEN DATE_PART('dow', REPORTDATE) = 4 THEN 3
                WHEN DATE_PART('dow', REPORTDATE) = 5 THEN 4
                WHEN DATE_PART('dow', REPORTDATE) = 6 THEN 5
                WHEN DATE_PART('dow', REPORTDATE) = 0 THEN 6
            END AS day_number,
            LPAD(CAST(DATE_PART('hour', REPORTDATE) AS VARCHAR), 2, '0') AS hour_number,
            SUM(COUNT) AS sum_count
        FROM crashes.crashes
        WHERE MODE IN ${inputs.multi_mode_dd.value}
        AND SEVERITY IN ${inputs.multi_severity.value}
        AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
        GROUP BY day_of_week, day_number, hour_number
    )

    SELECT
        r.day_of_week,
        r.day_number,
        LPAD(r.hour_number::TEXT, 2, '0') AS hour_number,
        COALESCE(cd.sum_count, 0) AS sum_count
    FROM reference r
    LEFT JOIN count_data cd
    ON r.day_of_week = cd.day_of_week
    AND r.hour_number = cd.hour_number
    ORDER BY r.day_number, r.hour_number;
```

```sql time
    WITH reference AS (
        SELECT
            hr.hour_number
        FROM 
            GENERATE_SERIES(0, 23) AS hr(hour_number)
    ),
    count_data AS (
        SELECT
            LPAD(CAST(DATE_PART('hour', REPORTDATE) AS VARCHAR), 2, '0') AS hour_number,
            SUM(COUNT) AS sum_count
        FROM crashes.crashes
        WHERE MODE IN ${inputs.multi_mode_dd.value}
        AND SEVERITY IN ${inputs.multi_severity.value}
        AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
        GROUP BY hour_number
    )

    SELECT
        'Total' AS Total,
        LPAD(r.hour_number::TEXT, 2, '0') AS hour_number,
        COALESCE(cd.sum_count, 0) AS sum_count
    FROM reference r
    LEFT JOIN count_data cd
    ON r.hour_number = cd.hour_number
    ORDER BY r.hour_number;
```

```sql day
    WITH reference AS (
        SELECT
            dow.day_of_week,
            dow.day_number,
            'Total' AS total
        FROM 
            (VALUES 
                ('Sun', 0), ('Mon', 1), ('Tue', 2), 
                ('Wed', 3), ('Thu', 4), ('Fri', 5), ('Sat', 6)
            ) AS dow(day_of_week, day_number)
    ),
    count_data AS (
        SELECT
            CASE
                WHEN DATE_PART('dow', REPORTDATE) = 0 THEN 'Sun'
                WHEN DATE_PART('dow', REPORTDATE) = 1 THEN 'Mon'
                WHEN DATE_PART('dow', REPORTDATE) = 2 THEN 'Tue'
                WHEN DATE_PART('dow', REPORTDATE) = 3 THEN 'Wed'
                WHEN DATE_PART('dow', REPORTDATE) = 4 THEN 'Thu'
                WHEN DATE_PART('dow', REPORTDATE) = 5 THEN 'Fri'
                WHEN DATE_PART('dow', REPORTDATE) = 6 THEN 'Sat'
            END AS day_of_week,
            CASE
                WHEN DATE_PART('dow', REPORTDATE) = 1 THEN 0
                WHEN DATE_PART('dow', REPORTDATE) = 2 THEN 1
                WHEN DATE_PART('dow', REPORTDATE) = 3 THEN 2
                WHEN DATE_PART('dow', REPORTDATE) = 4 THEN 3
                WHEN DATE_PART('dow', REPORTDATE) = 5 THEN 4
                WHEN DATE_PART('dow', REPORTDATE) = 6 THEN 5
                WHEN DATE_PART('dow', REPORTDATE) = 0 THEN 6
            END AS day_number,
            SUM(COUNT) AS sum_count
        FROM crashes.crashes
        WHERE MODE IN ${inputs.multi_mode_dd.value}
        AND SEVERITY IN ${inputs.multi_severity.value}
        AND REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
        GROUP BY day_of_week, day_number
    )

    SELECT
        r.day_of_week,
        r.day_number,
        r.total,
        COALESCE(cd.sum_count, 0) AS sum_count
    FROM reference r
    LEFT JOIN count_data cd
    ON r.day_of_week = cd.day_of_week
    ORDER BY r.day_number;
```

```sql hex_map
    SELECT
        h.GRID_ID,
        COALESCE(SUM(c.COUNT), 0) AS Injuries,
        '/hexgrid/' || h.GRID_ID AS link
    FROM
        hexgrid.crash_hexgrid h
    LEFT JOIN
        crashes.crashes c ON h.GRID_ID = c.GRID_ID
        AND c.MODE IN ${inputs.multi_mode_dd.value}
        AND c.SEVERITY IN ${inputs.multi_severity.value}
        AND c.REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
    GROUP BY
        h.GRID_ID
```

```sql ward_map
    SELECT
        w.WARD_ID AS WARD,
        COALESCE(SUM(c.COUNT), 0) AS Injuries
    FROM
        wards.wards_2022 w
    LEFT JOIN
        crashes.crashes c
    ON
        w.WARD_ID = c.WARD
        AND c.MODE IN ${inputs.multi_mode_dd.value}
        AND c.SEVERITY IN ${inputs.multi_severity.value}
        AND c.REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
    GROUP BY
        w.WARD_ID
    ORDER BY
        w.WARD_ID;
```

```sql anc_map
    SELECT
        a.ANC,
        COALESCE(SUM(c.COUNT), 0) AS Injuries,
        '/anc/' || a.ANC AS link
    FROM
        anc.anc_2023 a
    LEFT JOIN
        crashes.crashes c ON a.ANC = c.ANC
        AND c.MODE IN ${inputs.multi_mode_dd.value}
        AND c.SEVERITY IN ${inputs.multi_severity.value}
        AND c.REPORTDATE BETWEEN '${inputs.date_range.start}' AND '${inputs.date_range.end}'
    GROUP BY
        a.ANC
```

```sql yoy_mode
    WITH modes_and_severities AS (
        SELECT DISTINCT 
            MODE
        FROM 
            crashes.crashes
    ), 
    current_year AS (
        SELECT 
            MODE,
            SUM(COUNT) as sum_count,
            EXTRACT(YEAR FROM current_date) as current_year
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY IN ${inputs.multi_severity.value} 
            AND REPORTDATE >= date_trunc('year', current_date)
        GROUP BY 
            MODE
    ), 
    prior_year AS (
        SELECT 
            MODE,
            SUM(COUNT) as sum_count
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY IN ${inputs.multi_severity.value} 
            AND REPORTDATE >= (date_trunc('year', current_date) - INTERVAL '1 year')
            AND REPORTDATE < (current_date - INTERVAL '1 year')
        GROUP BY 
            MODE
    ), 
    total_counts AS (
        SELECT 
            SUM(cy.sum_count) AS total_current_year,
            SUM(py.sum_count) AS total_prior_year
        FROM 
            current_year cy
        FULL JOIN 
            prior_year py 
        ON 
            cy.MODE = py.MODE
    )
    SELECT 
        mas.MODE,
        COALESCE(cy.sum_count, 0) as current_year_sum, 
        COALESCE(py.sum_count, 0) as prior_year_sum, 
        COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) as difference,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) = 0 THEN 
                NULL 
            WHEN COALESCE(py.sum_count, 0) != 0 THEN 
                ((COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)) / COALESCE(py.sum_count, 0)) 
            ELSE 
                NULL 
        END as percentage_change,
        EXTRACT(YEAR FROM current_date) as current_year,
        (total_current_year - total_prior_year) / NULLIF(total_prior_year, 0) AS total_percentage_change
    FROM 
        modes_and_severities mas
    LEFT JOIN 
        current_year cy 
    ON 
        mas.MODE = cy.MODE
    LEFT JOIN 
        prior_year py 
    ON 
        mas.MODE = py.MODE,
    total_counts
```

```sql yoy_severity
    WITH severities AS (
        SELECT DISTINCT 
            SEVERITY
        FROM 
            crashes.crashes
    ), 
    current_year AS (
        SELECT 
            SEVERITY,
            SUM(COUNT) as sum_count,
            EXTRACT(YEAR FROM current_date) as current_year
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY IN ${inputs.multi_severity.value} 
            AND REPORTDATE >= date_trunc('year', current_date)
        GROUP BY 
            SEVERITY
    ), 
    prior_year AS (
        SELECT 
            SEVERITY,
            SUM(COUNT) as sum_count
        FROM 
            crashes.crashes 
        WHERE 
            SEVERITY IN ${inputs.multi_severity.value} 
            AND REPORTDATE >= (date_trunc('year', current_date) - INTERVAL '1 year')
            AND REPORTDATE < (current_date - INTERVAL '1 year')
        GROUP BY 
            SEVERITY
    ),
    total_sums AS (
        SELECT
            SUM(cy.sum_count) as total_current_year_sum,
            SUM(py.sum_count) as total_prior_year_sum
        FROM 
            severities s
        LEFT JOIN 
            current_year cy 
        ON 
            s.SEVERITY = cy.SEVERITY
        LEFT JOIN 
            prior_year py 
        ON 
            s.SEVERITY = py.SEVERITY
        WHERE 
            cy.sum_count IS NOT NULL OR py.sum_count IS NOT NULL
    )
    SELECT 
        s.SEVERITY,
        cy.sum_count as current_year_sum, 
        py.sum_count as prior_year_sum, 
        cy.sum_count - py.sum_count as difference,
        CASE 
            WHEN cy.sum_count = 0 THEN 
                NULL
            WHEN py.sum_count != 0 THEN 
                ((cy.sum_count - py.sum_count) / py.sum_count) 
            ELSE 
                NULL 
        END as percentage_change,
        t.total_current_year_sum,
        t.total_prior_year_sum,
        CASE
            WHEN t.total_prior_year_sum != 0 THEN
                ((t.total_current_year_sum - t.total_prior_year_sum) / t.total_prior_year_sum)
            ELSE
                NULL
        END as total_percentage_change,
        EXTRACT(YEAR FROM current_date) as current_year
    FROM 
        severities s
    LEFT JOIN 
        current_year cy 
    ON 
        s.SEVERITY = cy.SEVERITY
    LEFT JOIN 
        prior_year py 
    ON 
        s.SEVERITY = py.SEVERITY
    JOIN
        total_sums t
    ON TRUE
    WHERE 
        cy.sum_count IS NOT NULL OR py.sum_count IS NOT NULL
```

```sql yoy_text_fatal
    WITH modes_and_severities AS (
        SELECT DISTINCT 
            SEVERITY 
        FROM 
            crashes.crashes
    ), 
    current_year AS (
        SELECT 
            SEVERITY, 
            sum(COUNT) as sum_count,
            extract(year from current_date) as current_year
        FROM 
            crashes.crashes 
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
            crashes.crashes 
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

```sql anc_yoy
    WITH unique_anc AS (
        SELECT 
            ANC 
        FROM 
            anc.anc_2023 
        GROUP BY 
            ANC
    ),
    current_year AS (
        SELECT 
            crashes.ANC, 
            sum(crashes.COUNT) as sum_count,
            extract(year from current_date) as current_year
        FROM 
            crashes.crashes 
        JOIN 
            unique_anc ua 
        ON 
            crashes.ANC = ua.ANC
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.REPORTDATE >= date_trunc('year', current_date)
        GROUP BY 
            crashes.ANC
    ), 
    prior_year AS (
        SELECT 
            crashes.ANC, 
            sum(crashes.COUNT) as sum_count
        FROM 
            crashes.crashes 
        JOIN 
            unique_anc ua 
        ON 
            crashes.ANC = ua.ANC
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.REPORTDATE >= (date_trunc('year', current_date) - interval '1 year')
            AND crashes.REPORTDATE < (current_date - interval '1 year')
        GROUP BY 
            crashes.ANC
    )
    SELECT 
        mas.ANC,
        '/anc/' || mas.ANC AS link,
        COALESCE(cy.sum_count, 0) as current_year_sum, 
        COALESCE(py.sum_count, 0) as prior_year_sum, 
        COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) as difference,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) = 0 THEN NULL
            WHEN COALESCE(py.sum_count, 0) != 0 THEN ((COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)) / COALESCE(py.sum_count, 0)) 
            WHEN COALESCE(py.sum_count, 0) != 0 AND COALESCE(cy.sum_count, 0) = 0 THEN -1
            ELSE NULL 
        END as percentage_change,
        extract(year from current_date) as current_year
    FROM 
        unique_anc mas
    LEFT JOIN 
        current_year cy 
    ON 
        mas.ANC = cy.ANC
    LEFT JOIN 
        prior_year py 
    ON 
        mas.ANC = py.ANC;
```

```sql ward_yoy
    WITH unique_ward AS (
        SELECT 
            WARD_ID AS WARD 
        FROM 
            wards.wards_2022
        GROUP BY 
            WARD_ID
    ),
    current_year AS (
        SELECT 
            crashes.WARD, 
            sum(crashes.COUNT) as sum_count,
            extract(year from current_date) as current_year
        FROM 
            crashes.crashes 
        JOIN 
            unique_ward ua 
        ON 
            crashes.WARD = ua.WARD
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.REPORTDATE >= date_trunc('year', current_date)
        GROUP BY 
            crashes.WARD
    ), 
    prior_year AS (
        SELECT 
            crashes.WARD, 
            sum(crashes.COUNT) as sum_count
        FROM 
            crashes.crashes 
        JOIN 
            unique_ward ua 
        ON 
            crashes.WARD = ua.WARD
        WHERE 
            crashes.SEVERITY IN ${inputs.multi_severity.value} 
            AND crashes.REPORTDATE >= (date_trunc('year', current_date) - interval '1 year')
            AND crashes.REPORTDATE < (current_date - interval '1 year')
        GROUP BY 
            crashes.WARD
    ),
    totals AS (
        SELECT 
            SUM(COALESCE(cy.sum_count, 0)) AS current_year_total,
            SUM(COALESCE(py.sum_count, 0)) AS prior_year_total
        FROM 
            unique_ward mas
        LEFT JOIN 
            current_year cy 
        ON 
            mas.WARD = cy.WARD
        LEFT JOIN 
            prior_year py 
        ON 
            mas.WARD = py.WARD
    )
    SELECT 
        mas.WARD,
        COALESCE(cy.sum_count, 0) as current_year_sum, 
        COALESCE(py.sum_count, 0) as prior_year_sum, 
        COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0) as difference,
        CASE 
            WHEN COALESCE(cy.sum_count, 0) = 0 THEN NULL
            WHEN COALESCE(py.sum_count, 0) != 0 THEN ((COALESCE(cy.sum_count, 0) - COALESCE(py.sum_count, 0)) / COALESCE(py.sum_count, 0)) 
            WHEN COALESCE(py.sum_count, 0) != 0 AND COALESCE(cy.sum_count, 0) = 0 THEN -1
            ELSE NULL 
        END as percentage_change,
        extract(year from current_date) as current_year,
        CASE 
            WHEN totals.prior_year_total != 0 THEN (
                (totals.current_year_total - totals.prior_year_total) / totals.prior_year_total
            )
            ELSE NULL
        END AS total_percentage_change
    FROM 
        unique_ward mas
    LEFT JOIN 
        current_year cy 
    ON 
        mas.WARD = cy.WARD
    LEFT JOIN 
        prior_year py 
    ON 
        mas.WARD = py.WARD
    CROSS JOIN 
        totals;
```

```sql intersections_table
    SELECT
        c.INTERSECTIONNAME,
        h.GRID_ID,
        '/hexgrid/' || h.GRID_ID AS link
    FROM
        hexgrid.crash_hexgrid h
    LEFT JOIN
        intersections.intersections c ON h.GRID_ID = c.GRID_ID
```

<DateRange
  start='2018-01-01'
  title="Select Time Period"
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
    defaultValue={['Fatal', 'Major']}
/>

### Injuries by Mode and Severity

<Grid cols=2>
    <Group>
        <BarChart 
            title="Selected Period"
            chartAreaHeight=300
            subtitle="Mode"
            data={barchart_mode}
            x=MODE
            y=sum_count
            series=SEVERITY
            seriesColors={{"Major": '#ff9412',"Minor": '#ffdf00',"Fatal": '#ff5a53'}}
            swapXY=true
            labels=true
            leftPadding=20
            echartsOptions={{animation: false}}
        />
        <Note>
            *Fatal only.
        </Note>
    </Group>
        <Group>
        <DataTable data={yoy_mode} totalRow=true sort="current_year_sum desc" wrapTitles=true rowShading=true title="Year Over Year Difference">
            <Column id=MODE wrap=true totalAgg="Total"/>
            <Column id=current_year_sum title={`${yoy_mode[0].current_year} YTD`} />
            <Column id=prior_year_sum title={`${yoy_mode[0].current_year - 1} YTD`}  />
            <Column id=difference contentType=delta downIsGood=True title="Diff"/>
            <Column id=percentage_change fmt=pct title="% Diff" totalAgg={yoy_mode[0].total_percentage_change} totalFmt=pct/> 
        </DataTable>
        <DataTable data={yoy_severity} totalRow=true sort="current_year_sum desc" wrapTitles=true rowShading=true>
            <Column id=SEVERITY wrap=true totalAgg="Total"/>
            <Column id=current_year_sum title={`${yoy_mode[0].current_year} YTD`} />
            <Column id=prior_year_sum title={`${yoy_mode[0].current_year - 1} YTD`}  />
            <Column id=difference contentType=delta downIsGood=True title="Diff"/>
            <Column id=percentage_change fmt=pct title="% Diff" totalAgg={yoy_mode[0].total_percentage_change} totalFmt=pct /> 
        </DataTable>
        <Note>
            The results for both tables will depend on your severity selection above; by default, it displays "Major" and "Fatal" severity.
        </Note>
        <Note>
            *Fatal only.
        </Note>
    </Group>
</Grid>

<Dropdown
    data={unique_mode} 
    name=multi_mode_dd
    value=MODE
    title="Select Mode"
    multiple=true
    selectAllByDefault=true
    description="*Only fatal"
/>

### Injuries Heatmap

<Grid cols=2>
    <Group>
        <Note>
            Select a hexagon to zoom in and view more details about the injuries resulting from a crash within it.
        </Note>
        <BaseMap
            height=560
            startingZoom=12
        >
            <Areas data={hex_map} geoJsonUrl='/crash-hexgrid.geojson' geoId=GRID_ID areaCol=GRID_ID value=Injuries link=link min=0 opacity=0.7 />
            <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00/ ignoreZoom=true 
            tooltip={[
                {id: 'ROUTENAME'}
            ]}
            />
        </BaseMap>
        <Note>
        The purple lines represent DC's High Injury Network  
        </Note>
        <DataTable data={intersections_table} title= "Intersection Search" subtitle="Use the Intersection Search function to pinpoint an intersection within a hexagon" search=true wrapTitles=true rowShading=true rows=3 link=link downloadable=false>
            <Column id=INTERSECTIONNAME title=" "/>
        </DataTable>
    </Group>
    <Group>
        <Heatmap 
            data={day}
            title="Injuries by Day of Week & Time of the Day"
            subtitle=" "
            x=day_of_week xSort=day_number
            y=total
            value=sum_count
            legend=true
            valueLabels=true
            mobileValueLabels=true
            chartAreaHeight=50
        />    
        <Heatmap 
            data={day_time} 
            subtitle="24-Hour Format"
            x=hour_number xSort=hour_number
            y=day_of_week ySort=day_number
            value=sum_count
            legend=true
            filter=true
            mobileValueLabels=true
        />
        <Heatmap 
            data={time} 
            subtitle="24-Hour Format"
            x=hour_number xSort=hour_number
            y=Total
            value=sum_count
            legend=true
            filter=true
            chartAreaHeight=50
            mobileValueLabels=true
        />
    </Group>
</Grid>

### Injuries by Ward & ANC
<Note>
    Select an ANC to zoom in and see more details about the injuries resulting from a crash within its SMDs."
</Note>
<Grid cols=2>
    <Group>
        <BaseMap
            height=470
            startingZoom=11
            title="ANC"
        >
        <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00 ignoreZoom=true
            tooltip={[
                {id: 'ROUTENAME'}
            ]}
        />
        <Areas data={anc_map} geoJsonUrl='/anc_2023.geojson' geoId=ANC areaCol=ANC value=Injuries link=link min=0 opacity=0.7 borderWidth=1 borderColor='#A9A9A9'/>
        </BaseMap>
        <Note>
            The purple lines represent DC's High Injury Network
        </Note>
        <DataTable data={anc_yoy} sort="current_year_sum desc" title="Year Over Year Difference" search=true wrapTitles=true rowShading=true link=link>
            <Column id=ANC title="ANC"/>
            <Column id=current_year_sum title={`${yoy_mode[0].current_year} YTD`} />
            <Column id=prior_year_sum title={`${yoy_mode[0].current_year - 1} YTD`}  />
            <Column id=difference title="Diff" contentType=delta downIsGood=True />
            <Column id=percentage_change fmt=pct0 title="% Diff"/> 
        </DataTable>
    </Group>
        <Group>
        <BaseMap
            height=470
            startingZoom=11
            title="Ward"
        >
        <Areas data={unique_hin} geoJsonUrl='/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00 ignoreZoom=true
            tooltip={[
                {id: 'ROUTENAME'}
            ]}
        />
        <Areas data={ward_map} geoJsonUrl='/Wards_from_2022.geojson' geoId=WARD_ID areaCol=WARD value=Injuries min=0 opacity=0.7 borderWidth=1 borderColor='#A9A9A9'
            tooltip={[
                {id:'WARD', title:"Ward", valueClass: 'text-base font-semibold', fieldClass: 'text-base font-semibold'},
                {id:'Injuries'}
            ]}
        />
        </BaseMap>
        <Note>
            The purple lines represent DC's High Injury Network
        </Note>
        <DataTable data={ward_yoy} sort="current_year_sum desc" title="Year Over Year Difference" totalRow=true search=true wrapTitles=true rowShading=true>
            <Column id=WARD title="Ward" totalAgg="Total"/>
            <Column id=current_year_sum title={`${yoy_mode[0].current_year} YTD`} />
            <Column id=prior_year_sum title={`${yoy_mode[0].current_year - 1} YTD`}  />
            <Column id=difference title="Diff" contentType=delta downIsGood=True />
            <Column id=percentage_change fmt=pct title="% Diff" totalAgg={ward_yoy[0].total_percentage_change} totalFmt=pct/> 
        </DataTable>
    </Group>
</Grid>
<Note>
    The tables are sorted in descending order by default based on the <Value data={yoy_text_fatal} column="current_year" fmt='####'/> YTD injuries.
</Note>

<!---
<LastRefreshed prefix="Data last updated" printShowDate=True fmt='mmmm d, yyyy'/>
-->

<Details title="About the data">

The data come from the tables Crashes in DC and Crash Details from DC's Open Data portal (see links below), as well as internal tracking of traffic fatalities by the District Department of Transportation (DDOT) and the Metropolitan Police Department (MPD). 
    
### The data is filtered to:
        - Only keep records of crashes that occured on or after 1/1/2017
        - Only keep records of crashes that involved a fatality, a major injury, or minor injury. See section "Injury Crashes" below. 

All counts on this page are for persons injured, NOT the number of crashes. For example, one crash may involve injuries to three persons; in that case, all three persons will be counted in all the charts and indicators on this dashboard. 

Injury Crashes are defined based on information collected at the scene of the crash. See below for examples of the different types of injury categories. 

### Injury Category:
        - Major Injury:	Unconsciousness; Apparent Broken Bones; Concussion; Gunshot (non-fatal); Severe Laceration; Other Major Injury. 
        - Minor Injury:	Abrasions; Minor Cuts; Discomfort; Bleeding; Swelling; Pain; Apparent Minor Injury; Burns-minor; Smoke Inhalation; Bruises

While the injury crashes shown on this map include any type of injury, summaries of injuries submitted for federal reports only include those that fall under the Model Minimum Uniform Crash Criteria https://www.nhtsa.gov/mmucc-1, which do not include "discomfort" and "pain". Note: Data definitions of injury categories may differ due to source (e.g., federal rules) and may change over time, which may cause numbers to vary among data sources. 

All data comes from MPD. 

    - Crashes in DC (Open Data): https://opendata.dc.gov/datasets/crashes-in-dc
    - Crash Details (Open Data): https://opendata.dc.gov/datasets/crash-details-table

</Details>