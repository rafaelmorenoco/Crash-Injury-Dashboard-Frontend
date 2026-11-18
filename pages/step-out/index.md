---
title: Pedestrian Step-Out Enforcement (BETA)
queries:
   - last_record: last_record.sql
sidebar_link: false
---

<!--
  Data prerequisites:
    crashes.crashes    needs CROSSING_SITE_ID from the backend (assign_crossing_sites())
    stepout.sites      <- crossing_sites.parquet   (backend crossings/build_crossing_sites.py,
                          copied in by the monthly reference layer refresh)
                          SITE_ID, SITE_TYPE, SITE_NAME, CONTROL, DEVICE, DEVICES,
                          N_DEVICES, INTERSECTIONKEY, PSA, POLICEDISTRICT, LATITUDE, LONGITUDE
    stepout.devices    <- crossing_devices.parquet (same script): SITE_ID, DEVICE, DETAIL,
                          LATITUDE, LONGITUDE
    static/Intersection_Points_buffers.geojson   100 ft radius for intersection sites

  A site is an uncontrolled pedestrian crossing: an unsignalized intersection or
  a midblock crossing with an RRFB, LED flasher, HAWK beacon, in-street yield
  sign, or crossing sign, plus every two-way stop intersection. A crash counts
  at an intersection site within 100 ft of the intersection, and at a midblock
  site within 100 ft of the crossing. Only pedestrians struck by a motor
  vehicle count, as points: 10 per person killed, 5 per serious injury, 1 per
  minor injury (DDOT High Injury Network methodology).

  Rank: by points, then people, then crashes, among sites of the selected control
  types. District and PSA narrow the list without re-ranking it.

  Selection wiring (mirrors pages/impaired-driving):
    map click   -> inputs.site_select.SITE_ID -> narrows site_base (the table's data)
    table click -> inputs.site_pick (WHERE fragment) -> site_filtered -> selected_site
-->

```sql date_bounds
-- Earliest selectable date and the default start: five years before the latest record.
SELECT strftime(MAX(LAST_RECORD)::DATE - INTERVAL 5 YEAR, '%Y-%m-%d') AS start_5y
FROM crashes.crashes
```

```sql unique_severity
SELECT SEVERITY FROM crashes.crashes GROUP BY 1
```

```sql unique_hin
SELECT GIS_ID, ROUTENAME FROM hin.hin GROUP BY ALL
```

```sql controls
SELECT CONTROL AS control,
       CASE CONTROL WHEN 'HAWK beacon' THEN 1 WHEN 'Two-way stop' THEN 2
                    WHEN 'Uncontrolled' THEN 3 WHEN 'Midblock' THEN 4 ELSE 5 END AS sort_order
FROM stepout.sites
GROUP BY 1
ORDER BY 2
```

```sql districts
SELECT POLICEDISTRICT AS district
FROM stepout.sites
WHERE POLICEDISTRICT IS NOT NULL
GROUP BY 1
ORDER BY 1
```

```sql psas
-- PSAs in the selected district (all PSAs when no district is selected)
SELECT PSA AS psa, 'PSA ' || PSA AS psa_label
FROM stepout.sites
WHERE PSA IS NOT NULL
  AND POLICEDISTRICT LIKE '${inputs.district.value}'
GROUP BY 1, 2
ORDER BY 1
```

```sql top_label
SELECT CASE '${inputs.top_n.value}'
    WHEN 'all' THEN 'All'
    ELSE 'Top ' || '${inputs.top_n.value}'
END AS label
```

```sql selected_date_range
WITH report_date_range AS (
    SELECT
      CASE
        WHEN '${inputs.date_range.end}'::DATE >= (SELECT MAX(LAST_RECORD) FROM crashes.crashes)::DATE
        THEN (SELECT MAX(LAST_RECORD) FROM crashes.crashes)::DATE + INTERVAL '1 day'
        ELSE '${inputs.date_range.end}'::DATE + INTERVAL '1 day'
      END AS end_date,
      '${inputs.date_range.start}'::DATE AS start_date
),
date_info AS (
    SELECT
      CASE
        WHEN start_date = DATE_TRUNC('year', start_date)
         AND end_date   = DATE_TRUNC('year', start_date) + INTERVAL '1 year'
        THEN EXTRACT(YEAR FROM start_date)::VARCHAR
        WHEN start_date = DATE_TRUNC('year', CURRENT_DATE)
         AND '${inputs.date_range.end}'::DATE = end_date - INTERVAL '1 day'
        THEN EXTRACT(YEAR FROM (end_date - INTERVAL '1 day'))::VARCHAR || ' YTD'
        ELSE strftime(start_date, '%m/%d/%y') || '-' || strftime(end_date - INTERVAL '1 day', '%m/%d/%y')
      END AS current_period_range
    FROM report_date_range
)
SELECT current_period_range FROM date_info
```

```sql ped_crashes
-- Pedestrians struck by a motor vehicle at a crossing site, in the selected dates and severities.
SELECT
    CROSSING_SITE_ID AS SITE_ID,
    CCN,
    REPORTDATE,
    SEVERITY,
    "COUNT",
    CASE SEVERITY WHEN 'Fatal' THEN 10 WHEN 'Major' THEN 5 WHEN 'Minor' THEN 1 ELSE 0 END
        * "COUNT" AS pts,
    LATITUDE,
    LONGITUDE
FROM crashes.crashes
WHERE CROSSING_SITE_ID IS NOT NULL
  AND MODE = 'Pedestrian'
  AND INVOLVES_MOTOR_VEHICLE
  AND SEVERITY IN ${inputs.multi_severity.value}
  AND REPORTDATE BETWEEN ('${inputs.date_range.start}'::DATE)
                     AND (('${inputs.date_range.end}'::DATE) + INTERVAL '1 day')
```

```sql site_rank
-- Every site with a pedestrian injury in the filters, ranked among the selected control types.
WITH site_raw AS (
    SELECT
        SITE_ID, SITE_TYPE, CONTROL, DEVICE, DEVICES, PSA AS psa, POLICEDISTRICT AS district,
        LATITUDE, LONGITUDE,
        -- Street types abbreviated, whole words only (same list as the impaired driving page)
        TRIM(
          REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
          REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            ' ' || SITE_NAME || ' ',
            ' STREET ', ' ST '), ' AVENUE ', ' AVE '), ' ROAD ', ' RD '),
            ' PLACE ', ' PL '), ' COURT ', ' CT '), ' CIRCLE ', ' CIR '),
            ' BOULEVARD ', ' BLVD '), ' DRIVE ', ' DR '), ' TERRACE ', ' TER '),
            ' PARKWAY ', ' PKWY '), ' EXPRESSWAY ', ' EXPY '), ' LANE ', ' LN ')
        ) AS full_name
    FROM stepout.sites
    WHERE CONTROL IN ${inputs.control.value}
),
site_attr AS (
    -- MPD style keeps only the start of a block range ("1400 - 1499 BLOCK OF" -> "1400 BLOCK OF")
    SELECT * EXCLUDE (full_name),
        REGEXP_REPLACE(full_name, ' - [0-9]+ BLOCK OF ?', ' BLOCK OF ') AS site_name
    FROM site_raw
),
agg AS (
    SELECT
        SITE_ID,
        SUM(pts)                                                     AS ped_pts,
        SUM("COUNT")                                                 AS ped_people,
        COUNT(DISTINCT CCN)                                          AS crashes,
        SUM(CASE WHEN SEVERITY IN ('Fatal', 'Major') THEN "COUNT" ELSE 0 END) AS ksi
    FROM ${ped_crashes}
    GROUP BY SITE_ID
),
ranked AS (
    SELECT a.*, g.ped_pts, g.ped_people, g.crashes, g.ksi,
        RANK() OVER (ORDER BY g.ped_pts DESC, g.ped_people DESC, g.crashes DESC) AS city_rank
    FROM site_attr a
    JOIN agg g USING (SITE_ID)
)
SELECT
    SITE_ID,
    site_name,
    SITE_TYPE AS site_type,
    CONTROL   AS control,
    DEVICE    AS device,
    DEVICES   AS devices,
    district,
    psa,
    'PSA ' || psa || ' · ' || CONTROL
        || CASE WHEN DEVICE = 'None' THEN '' ELSE ' · ' || DEVICES END AS site_sub,
    city_rank,
    ped_pts, ped_people, crashes, ksi,
    LATITUDE, LONGITUDE
FROM ranked
WHERE district LIKE '${inputs.district.value}'
  -- a PSA left over from another district is ignored rather than emptying the page
  AND (psa LIKE '${inputs.psa.value}'
       OR '${inputs.psa.value}' NOT IN (SELECT psa FROM ${psas}))
QUALIFY ROW_NUMBER() OVER (ORDER BY city_rank, site_name, SITE_ID)
        <= CASE WHEN '${inputs.top_n.value}' = 'all' THEN 1000000
                ELSE CAST('${inputs.top_n.value}' AS INTEGER) END
```

```sql site_map
-- Lowest first, so the highest-ranked points are drawn on top.
SELECT * FROM ${site_rank}
ORDER BY city_rank DESC
```

```sql site_base
-- The table's data, narrowed to one site by a map click.
SELECT *
FROM ${site_rank}
WHERE (CASE
        WHEN length('${inputs.site_select.SITE_ID}') >= 32
            THEN SITE_ID = '${inputs.site_select.SITE_ID}'
        ELSE TRUE
       END)
ORDER BY city_rank, site_name
```

```sql site_filtered
SELECT * FROM ${site_base}
WHERE ${inputs.site_pick}
```

```sql selected_site
-- Exactly one row iff the scope has narrowed to a single site.
SELECT *,
    CASE WHEN site_type = 'Intersection' THEN SITE_ID END AS INTERSECTIONKEY
FROM (SELECT *, COUNT(*) OVER () AS n FROM ${site_filtered})
WHERE n = 1
```

```sql sel_breakdown
SELECT
    SUM(CASE WHEN SEVERITY = 'Fatal' THEN "COUNT" ELSE 0 END) AS killed,
    SUM(CASE WHEN SEVERITY = 'Major' THEN "COUNT" ELSE 0 END) AS major,
    SUM(CASE WHEN SEVERITY = 'Minor' THEN "COUNT" ELSE 0 END) AS minor,
    SUM(pts) AS points
FROM ${ped_crashes}
WHERE SITE_ID IN (SELECT SITE_ID FROM ${selected_site})
```

```sql sel_crashes
-- One row per crash at the selected site, newest first.
SELECT
    strftime(MIN(REPORTDATE), '%m/%d/%Y %H:%M') AS crash_time,
    MIN(REPORTDATE) AS sort_time,
    CASE
        WHEN SUM(CASE WHEN SEVERITY = 'Fatal' THEN 1 ELSE 0 END) > 0 THEN 'Fatal'
        WHEN SUM(CASE WHEN SEVERITY = 'Major' THEN 1 ELSE 0 END) > 0 THEN 'Serious'
        ELSE 'Minor'
    END AS worst,
    SUM("COUNT") AS pedestrians,
    SUM(pts) AS points,
    ANY_VALUE(LATITUDE) AS LATITUDE,
    ANY_VALUE(LONGITUDE) AS LONGITUDE
FROM ${ped_crashes}
WHERE SITE_ID IN (SELECT SITE_ID FROM ${selected_site})
GROUP BY CCN
ORDER BY sort_time DESC
```

```sql sel_devices
SELECT DEVICE AS device, COALESCE(DETAIL, '') AS detail, LATITUDE, LONGITUDE
FROM stepout.devices
WHERE SITE_ID IN (SELECT SITE_ID FROM ${selected_site})
ORDER BY device
```

Ranks uncontrolled pedestrian crossings in DC by the people hurt there, to help MPD choose sites for **pedestrian step-out (crosswalk) enforcement**: operations where drivers who fail to yield to a pedestrian in a crosswalk are stopped.

<Alert status="info">
Select a site on the map or a row in the table to see it up close. Select it again to clear. Use the map or the table, not both: clear one selection before starting a new one in the other.
</Alert>

<DateRange
start={
  (date_bounds && date_bounds[0] && date_bounds[0].start_5y)
  ? `${date_bounds[0].start_5y}`
  : '2021-01-01'
}
end={
  (last_record && last_record[0] && last_record[0].end_date)
  ? `${last_record[0].end_date}`
  : (() => {
      const twoDaysAgo = new Date(new Date().setDate(new Date().getDate() - 2));
      return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York' }).format(twoDaysAgo);
    })()
}
name="date_range"
presetRanges={['Last 12 Months', 'Year to Today', 'Last Year', 'All Time']}
description="Defaults to the last five years, the longest range available here ('All Time'). Pedestrian injuries at a single crossing are rare, so shorter ranges give less stable rankings. There is a two-day lag after the latest update."
/>

<Dropdown
data={unique_severity}
name="multi_severity"
value="SEVERITY"
title="Severity"
multiple={true}
defaultValue={['Fatal', 'Major', 'Minor']}
/>

<Dropdown
data={controls}
name="control"
value="control"
title="Crossing Control"
multiple={true}
order="sort_order"
defaultValue={['HAWK beacon', 'Two-way stop', 'Uncontrolled', 'Midblock']}
description="All-way stops are off by default: every approach already has to stop."
/>

<Dropdown data={districts} name="district" value="district" title="Police District" defaultValue="%">
    <DropdownOption value="%" valueLabel="All Districts"/>
</Dropdown>

<Dropdown name="top_n" title="Sites" defaultValue="100">
    <DropdownOption value="100" valueLabel="Top 100"/>
    <DropdownOption value="500" valueLabel="Top 500"/>
    <DropdownOption value="all" valueLabel="All"/>
</Dropdown>

<Dropdown data={psas} name="psa" value="psa" label="psa_label" title="PSA" defaultValue="%">
    <DropdownOption value="%" valueLabel="All PSAs"/>
</Dropdown>

<div class="invert-on-mobile">
<Grid cols=2>
    <Group>
        <div style="font-size: 14px;">
            <b>{`${top_label[0].label}`} Step-Out Enforcement Sites ({`${selected_date_range[0].current_period_range}`})</b>
            <span style="display:block; font-size: 12px; color: #6c757d;">
                Select a site on the map for details. Select it again to clear. Refresh the page to reset.
            </span>
        </div>
        <BaseMap
            height=560
            startingZoom=12
            basemap={`https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png?key=${import.meta.env.VITE_CARTO_KEY}`}
            attribution='© <a href="https://carto.com/attributions">CARTO</a>, © <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        >
            <Areas data={unique_hin} geoJsonUrl='https://raw.githubusercontent.com/rafaelmorenoco/Crash-Injury-Dashboard-Frontend/main/static/High_Injury_Network.geojson' geoId=GIS_ID areaCol=GIS_ID borderColor=#9d00ff color=#1C00ff00 ignoreZoom=true
                tooltip={[{id: 'ROUTENAME'}]} />
            <Points data={site_map} name=site_select lat=LATITUDE long=LONGITUDE value=ped_pts min=0 opacity=0.8 ignoreZoom=false
                tooltip={[
                    {id: 'site_name', valueClass: 'text-l font-semibold', showColumnName: false},
                    {id: 'site_sub', showColumnName: false},
                    {id: 'city_rank', title: 'Rank'},
                    {id: 'ped_pts', title: 'Pedestrian Injuries (points)'},
                    {id: 'ped_people', title: 'Pedestrians Injured (count)'},
                    {id: 'crashes', title: 'Crashes (count)'}
                ]} />
        </BaseMap>
        <Note>Each dot is an uncontrolled crossing: an intersection or a midblock crossing. The purple lines represent DC's High Injury Network.</Note>
        <Note>
            The latest crash record in the dataset is from <Value data={last_record} column="latest_record"/> and the data was last updated on <Value data={last_record} column="latest_update"/> hrs.
        </Note>
    </Group>
    <Group>
        <div style="font-size: 14px; margin-bottom: 4px;">
            <b>{`${top_label[0].label}`} Step-Out Sites Ranked by Pedestrian Injuries ({`${selected_date_range[0].current_period_range}`})</b>
            <span style="display:block; font-size: 12px; color: #6c757d;">
                Select a row to see the site up close. Select it again to clear. Select a header to sort.
            </span>
        </div>
        {#if site_base.length > 0}
        <SelectableTable
            data={site_base}
            name=site_pick
            valueCol=SITE_ID
            itemLabel=sites
            rows=12
            rowShading=true
            collapseOnSelect=true
            wrapTitles=true
            columns={[
                // Headers use non-breaking hyphens (U+2011) and spaces so units never wrap alone.
                { id: 'city_rank',  title: 'Rank', fmt: 'num' },
                { id: 'site_name',  title: 'Site', sub: 'site_sub' },
                { id: 'ped_pts',    title: 'Pedestrian Injuries (points)', fmt: 'num', colorscale: true, colorMin: 0 },
                { id: 'ped_people', title: 'Pedestrians Injured (count)', fmt: 'num' },
                { id: 'ksi',        title: 'Killed or Seriously Injured (count)', fmt: 'num' },
                { id: 'crashes',    title: 'Crashes (count)', fmt: 'num' }
            ]}
            initialSort={{ col: 'city_rank', dir: 'asc' }}
        />
        <Note>
            Points are not crash counts: 10 per pedestrian killed, 5 per serious injury, 1 per minor injury. Ties in points rank by people injured, then crashes.<br/>
            Rank covers the selected crossing controls; the Sites, District, and PSA filters narrow the list without re-ranking it.
        </Note>
        {:else}
        <Note>
            No sites have pedestrian injuries for the selected filters. Try a longer date range, more crossing controls, or another district or PSA.
        </Note>
        {/if}

        {#if selected_site.length === 1}
        <div style="font-size: 14px; margin-top: 12px;">
            <b>{selected_site[0].site_name}</b>
            <span style="display:block; font-size: 12px; color: #6c757d;">
                {selected_site[0].control} · {selected_site[0].district} · PSA {selected_site[0].psa} · rank {selected_site[0].city_rank}
            </span>
            <span style="display:block; font-size: 12px; color: #6c757d;">
                Devices: {selected_site[0].device === 'None' ? 'none in DDOT inventories (two-way stop)' : selected_site[0].devices}
            </span>
        </div>
        <BaseMap
            height=320
            startingZoom=18
            basemap={`https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png?key=${import.meta.env.VITE_CARTO_KEY}`}
            attribution='© <a href="https://carto.com/attributions">CARTO</a>, © <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        >
            {#if selected_site[0].site_type === 'Intersection'}
            <Areas data={selected_site} geoJsonUrl='https://raw.githubusercontent.com/rafaelmorenoco/Crash-Injury-Dashboard-Frontend/main/static/Intersection_Points_buffers.geojson' geoId=INTERSECTIONKEY areaCol=INTERSECTIONKEY color=#1C00ff00 borderColor='#dc2626' borderWidth=3 ignoreZoom=false
                tooltip={[{id: 'site_name', showColumnName: false}]} />
            {:else}
            <Points data={selected_site} lat=LATITUDE long=LONGITUDE color='#dc2626' opacity=0.9 ignoreZoom=false legend=false
                tooltip={[{id: 'site_name', showColumnName: false}]} />
            {/if}
            {#if sel_devices.length > 0}
            <Points data={sel_devices} lat=LATITUDE long=LONGITUDE color='#1d4ed8' opacity=0.9 ignoreZoom=true legend=false
                tooltip={[
                    {id: 'device', valueClass: 'text-l font-semibold', showColumnName: false},
                    {id: 'detail', showColumnName: false}
                ]} />
            {/if}
            {#if sel_crashes.length > 0}
            <Points data={sel_crashes} lat=LATITUDE long=LONGITUDE color='#f59e0b' opacity=0.9 ignoreZoom=true legend=false
                tooltip={[
                    {id: 'crash_time', valueClass: 'text-l font-semibold', showColumnName: false},
                    {id: 'worst', title: 'Most severe'},
                    {id: 'pedestrians', title: 'Pedestrians'}
                ]} />
            {/if}
        </BaseMap>
        <Note>
            {selected_site[0].site_type === 'Intersection' ? 'Red outline: the 100 ft radius around the intersection.' : 'Red dot: the midblock crossing; crashes within 100 ft count here.'} Blue dots: crossing devices. Orange dots: crashes that injured pedestrians.
        </Note>

        <DataTable data={sel_breakdown} rows=all rowShading=true wrapTitles=true title="Pedestrians Hurt at This Site">
            <Column id=killed title="Killed"/>
            <Column id=major  title="Seriously injured"/>
            <Column id=minor  title="Minor injury"/>
            <Column id=points title="Points"/>
        </DataTable>

        <DataTable data={sel_crashes} rows=8 rowShading=true wrapTitles=true title="Crashes ({sel_crashes.length})">
            <Column id=crash_time  title="Date and time"/>
            <Column id=worst       title="Most severe injury"/>
            <Column id=pedestrians title="Pedestrians injured"/>
            <Column id=points      title="Points"/>
        </DataTable>
        {/if}
    </Group>
</Grid>
</div>

<Details title="How to use this page">

Each **site** is an uncontrolled pedestrian crossing, where drivers must yield to people in the crosswalk without a traffic signal telling them to stop. That is where step-out enforcement applies. Sites come from DDOT's inventories, refreshed monthly:

- **Intersections** with a pedestrian crossing device (see below) and no traffic signal, plus **every two-way stop**: an intersection with stop signs on some approaches but no "All Way" plaque. At a two-way stop, the crosswalks across the street that does not stop are uncontrolled, whether or not a crossing sign is posted.
- **Midblock crossings**: crossing devices more than 100 feet from any intersection.

Crossing devices, strongest first: **HAWK beacon** (pedestrian hybrid beacon), **RRFB** (rectangular rapid flashing beacon), **LED pedestrian flasher**, **in-street yield sign** ("State law: yield to pedestrians"), and **pedestrian or school crossing sign** with the downward arrow plaque that marks the crossing itself. Removed devices and signs not yet installed are left out. Each site lists its devices under its name.

HAWK beacons are signals, but drivers often do not know to stop during the flashing red phase, so they are included. **All-way stops** are included but off by default in the **Crossing Control** filter, since every approach already has to stop.

A crash counts at a site when it is within **100 feet** of the intersection or the midblock crossing. Only **pedestrians struck by a motor vehicle** count, as points by severity: **10 per pedestrian killed, 5 per serious injury, 1 per minor injury**, following the DDOT High Injury Network methodology. Sites rank by points; ties rank by pedestrians injured, then crashes.

**Reading the ranking.** Pedestrian injuries at any one crossing are rare, so one death (10 points) can put a site near the top. Read the counts next to the points: a site with several injured pedestrians and several crashes shows a pattern; a site with one crash may reflect a single event. Use the **Severity** filter to rank without deaths, or only on deaths and serious injuries.

Each site belongs to the PSA and police district its point falls in.

</Details>

<Details title="Data notes">

- **Signals.** Sites within 100 feet of a traffic signal (other than a HAWK beacon) are left out: those crossings are controlled. A pedestrian crossing sign near a signal usually serves a channelized right-turn lane.
- **Advance signs.** Crossing signs under an "Ahead" plaque warn of a crossing farther on, so they do not mark a site. Crossing signs with no plaque count only within 100 feet of an intersection; between intersections, a lone sign without a plaque is almost always an advance warning.
- **Crash location.** MPD's crash data has no "in crosswalk" field, so the 100-foot radius stands in for the crosswalk. A site's count can include pedestrians hit nearby but outside the crosswalk.
- **Coverage.** These sites hold a small share of the city's pedestrian injuries. About a quarter happen at signalized intersections, and more than half happen away from any intersection, mostly on blocks with no crossing device. The ranking compares uncontrolled crossings with one another; it is not a map of where most pedestrians are hurt.
- **Inventory gaps.** A crossing missing from DDOT's sign and device inventories is missing here. Two-way stops are detected from stop signs within 100 feet of an intersection with no "All Way" plaque.

</Details>

<style>
  /* On mobile, put the ranking table above the map (same as the impaired driving page). */
  @media (max-width: 639px) {
    .invert-on-mobile > :global(.grid) > :global(div:nth-child(1)) { order: 2; }
    .invert-on-mobile > :global(.grid) > :global(div:nth-child(2)) { order: 1; }
  }
</style>
