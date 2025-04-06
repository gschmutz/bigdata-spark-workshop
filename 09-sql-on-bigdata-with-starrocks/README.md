# Working with Starrocks



## Introduction

[Starrocks](https://starrocks.io/), a Linux Foundation project, is a next-generation sub-second MPP OLAP database for full analytics scenarios, including multi-dimensional analytics, real-time analytics, and ad-hoc queries. 

In this workshop we are using Starrocks to access the data we have available in the Object Storage. 

## Prepare the data, if no longer available

The data needed here has been uploaded in workshop 4 - [Data Reading and Writing using DataFrames](../04-spark-dataframe). You can skip this section, if you still have the data available in MinIO.

Create the flight bucket:
 
```bash
docker exec -ti minio-mc mc mb minio-1/flight-bucket
```

and then copy the refined data 

```bash
docker exec -ti minio-mc mc cp --recursive /data-transfer/flight-data/refined minio-1/flight-bucket/
```

## Using Starrocks to access Object Storage (tbd)

In order for us to use Trino with Object Storage or HDFS, we first have to create the necessary tables in Hive Metastore. Trino is using the Hive Metastore for a place to get the necessary metadata about the data itself (i.e. the table view on the raw data in object storage/HDFS)

### Create Airport Table in Hive Metastore

In order to access data in HDFS or Object Storage using Trino, we have to create a table in the Hive metastore. Note that the location `s3a://flight-bucket/refined/..` points to the data we have uploaded before.

Connect to Hive Metastore CLI

```bash
docker exec -ti hive-metastore hive
```

and on the command prompt first create a new database `flight_db` 

```sql
CREATE DATABASE flight_db;
```

switch into that database

```sql
USE flight_db;
```

and create a table `airport_t`:

```
CREATE EXTERNAL TABLE airport_t (iata string
                                , airport string
                                , city string                                
                                , state string
                                , country string
                                , lat double
                                , long double)
ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe'
LOCATION 's3a://flight-bucket/refined/airports';
```

Exit from the Hive Metastore CLI 

```
exit;
```

### Query Airport Table from Starrocks


