---
title: Age Distribution
queries:
   - last_record: last_record.sql
sidebar_position: 8
---

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

```sql age_severity
WITH buckets(bucket_order, bucket_label, lower_bound, upper_bound) AS (
    VALUES
        (0,    '0-10',   0,   10),
        (11,   '11-20',  11,  20),
        (21,   '21-30',  21,  30),
        (31,   '31-40',  31,  40),
        (41,   '41-50',  41,  50),
        (51,   '51-60',  51,  60),
        (61,   '61-70',  61,  70),
        (71,   '71-80',  71,  80),
        (81,   '> 80',  81,  110)
),
null_bucket AS (
    SELECT 9999 AS bucket_order, 'Null' AS bucket_label, 120 AS lower_bound, 120 AS upper_bound
),
all_buckets AS (
    SELECT * FROM buckets
    UNION ALL
    SELECT * FROM null_bucket
)
SELECT
    ab.bucket_label,
    c.SEVERITY,
    COALESCE(SUM(c.COUNT), 0) AS Injuries
FROM all_buckets ab
LEFT JOIN crashes.crashes c 
    ON (
         -- For the Null bucket, match records where AGE equals 120 exactly
         (ab.bucket_label = 'Null' AND CAST(c.AGE AS INTEGER) = ab.lower_bound)
         OR
         -- For all other buckets, match where AGE falls between the bucket's lower and upper bounds
         (ab.bucket_label <> 'Null' AND CAST(c.AGE AS INTEGER) BETWEEN ab.lower_bound AND ab.upper_bound)
       )
    AND c.MODE IN ${inputs.multi_mode_dd.value}
    AND c.SEVERITY IN ${inputs.multi_severity.value}
    AND c.REPORTDATE BETWEEN ('${inputs.date_range.start}'::DATE)
                         AND (('${inputs.date_range.end}'::DATE) + INTERVAL '1 day')
    AND c.AGE BETWEEN '${inputs.min_age}' AND '${inputs.max_age}'
GROUP BY ab.bucket_order, ab.bucket_label, c.SEVERITY
ORDER BY 
    ab.bucket_order,
    CASE 
        WHEN c.SEVERITY = 'Minor' THEN 1
        WHEN c.SEVERITY = 'Major' THEN 2
        WHEN c.SEVERITY = 'Fatal' THEN 3
    END;
```

```sql age_mode
WITH buckets(bucket_order, bucket_label, lower_bound, upper_bound) AS (
    VALUES
        (0,    '0-10',   0,   10),
        (11,   '11-20',  11,  20),
        (21,   '21-30',  21,  30),
        (31,   '31-40',  31,  40),
        (41,   '41-50',  41,  50),
        (51,   '51-60',  51,  60),
        (61,   '61-70',  61,  70),
        (71,   '71-80',  71,  80),
        (81,   '> 80',  81,  110)
),
null_bucket AS (
    SELECT 9999 AS bucket_order, 'Null' AS bucket_label, 120 AS lower_bound, 120 AS upper_bound
),
all_buckets AS (
    SELECT * FROM buckets
    UNION ALL
    SELECT * FROM null_bucket
)
SELECT
    ab.bucket_label,
    c.MODE,
    COALESCE(SUM(c.COUNT), 0) AS Injuries
FROM all_buckets ab
LEFT JOIN crashes.crashes c 
    ON (
         -- For the Null bucket, match records where AGE equals 120 exactly
         (ab.bucket_label = 'Null' AND CAST(c.AGE AS INTEGER) = ab.lower_bound)
         OR
         -- For all other buckets, match where AGE falls between the bucket's lower and upper bounds
         (ab.bucket_label <> 'Null' AND CAST(c.AGE AS INTEGER) BETWEEN ab.lower_bound AND ab.upper_bound)
       )
    AND c.MODE IN ${inputs.multi_mode_dd.value}
    AND c.SEVERITY IN ${inputs.multi_severity.value}
    AND c.REPORTDATE BETWEEN ('${inputs.date_range.start}'::DATE)
                         AND (('${inputs.date_range.end}'::DATE) + INTERVAL '1 day')
    AND c.AGE BETWEEN '${inputs.min_age}' AND '${inputs.max_age}'
GROUP BY ab.bucket_order, ab.bucket_label, c.MODE
ORDER BY ab.bucket_order,
    CASE 
        WHEN c.MODE = 'Bicyclist' THEN 1
        WHEN c.MODE = 'Pedestrian' THEN 2
        WHEN c.MODE = 'Other' THEN 3
        WHEN c.MODE = 'Driver' THEN 4
        WHEN c.MODE = 'Passenger' THEN 5
        WHEN c.MODE = 'Motorcyclist*' THEN 6
        WHEN c.MODE = 'Scooterist*' THEN 7
        ELSE 8  -- for any other cases, place them last
    END;
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
    defaultValue={['Fatal', 'Major']}
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

<Grid cols=2>
    <Group>
        <BarChart 
            data={age_severity}
            title="Age Distribution by Severity"
            chartAreaHeight=300
            x="bucket_label" 
            y="Injuries"
            labels={true} 
            yAxisTitle="Injuries" 
            series=SEVERITY
            seriesColors={{"Minor": '#ffdf00',"Major": '#ff9412',"Fatal": '#ff5a53'}}
            xAxisLabels={true} 
            xTickMarks={true} 
            leftPadding={10} 
            rightPadding={30}
            sort=false
            swapXY=true
        />
    </Group>
    <Group>
        <BarChart 
            data={age_mode}
            title="Age Distribution by Road User"
            chartAreaHeight=300
            x="bucket_label" 
            y="Injuries"
            labels={true} 
            yAxisTitle="Injuries" 
            series=MODE
            seriesColors={{"Bicyclist": '#00bf7d',"Driver": '#2546f0',"Motorcyclist*": '#029356',"Other": '#89ce00',"Passenger": '#00b4c5',"Pedestrian": '#5928ed',"Unknown": '#b3c7f7', "Scooterist*": '#bee3f9'}}
            xAxisLabels={true} 
            xTickMarks={true} 
            leftPadding={10} 
            rightPadding={30}
            sort=false
            swapXY=true
        />
    </Group>
</Grid>