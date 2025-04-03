---
title: ANC Level Data
queries:
   - anc_link: anc_link.sql
sidebar_link: false
---

Click on a ANC to see more detail


```sql anc_with_link
select *, '/anc/' || ANC as link
from ${anc_link}
```

<DataTable data={anc_with_link} link=link rows=all/>