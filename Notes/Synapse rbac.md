# Synapse Roles & Permissions



## SQL Pools

Schema permissions

```sql
GRANT CONTROL ON SCHEMA::demo TO [Synapse-builders]
```

- Allow all permissions on all the tables but **doesn't allow creating new tables**. 
- To allow creating new table, combine the above with

```sql
GRANT CREATE TABLE TO [CovidData-builders]
```

