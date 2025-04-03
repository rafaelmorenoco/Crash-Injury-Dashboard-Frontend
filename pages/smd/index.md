---
title: SMD Level Data
queries:
   - smd_link: smd_link.sql
sidebar_link: false
---

Click on a SMD to see more detail

```sql smd_with_link
select *, '/smd/' || SMD as link
from ${smd_link}
```

<DataTable data={smd_with_link} link=link rows=all/>