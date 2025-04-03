---
title: Hex Level Data
queries:
   - hex: hex.sql
sidebar_link: false
---

Click on a hex to see more detail


```sql hex_with_link
select *, '/hexgrid/' || GRID_ID as link
from ${hex}
```

<DataTable data={hex_with_link} link=link rows=all/>