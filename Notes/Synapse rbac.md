# Synapse Roles & Permissions



## SQL Pools

### Dedicated Pool

#### Schema permissions

```sql
GRANT CONTROL ON SCHEMA::demo TO [Synapse-builders]
```

- Allow all permissions on all the tables but **doesn't allow creating new tables**. 
- To allow creating new table, combine the above with

```sql
GRANT CREATE TABLE TO [CovidData-builders]
```



### Serverless Pool

Give access by creating a login **

```sql
CREATE LOGIN [aadUser@microsoft.com] FROM EXTERNAL PROVIDER;
```

Then add to the dbcreator role **

```sql
ALTER SERVER ROLE dbcreator ADD MEMBER [aadUser@microsoft.com]
```











## Synapse Studio



| Role                           | Scope                                     | Description                                                  |
| ------------------------------ | ----------------------------------------- | ------------------------------------------------------------ |
| **Synapse Artifact Publisher** | SQL Script files                          | Can create and publish. Executing depends on the permissions on the SQL Pools (SQL Server permissions) |
| **Synapse Artifact Publisher** | pipelines <br />datasets                  | Create and publish pipelines and datasets. BUT can't debug pipelines and can't preview dataset's data |
| **Contributor**                | Integration runtime interactive authoring | can enable it                                                |
|                                |                                           |                                                              |

[^**]: To be tested

