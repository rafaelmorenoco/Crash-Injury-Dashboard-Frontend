select 
    OBJECTID
from dbricks.crashes
where SEVERITY = 'Fatal'
group by all