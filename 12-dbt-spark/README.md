# Working with `dbt` and Spark

In this workshop we will work with [dbt](https://delta.io/), 

The same data as in the [Object Storage Workshop](../03-object-storage/README.md) will be used. We will show later how to re-upload the files, if you no longer have them available.
 
## Prepare the data, if no longer available

The data needed here has been uploaded in workshop 2 - [Working with MinIO Object Storage](02-object-storage). You can skip this section, if you still have the data available in MinIO. We are using the `mc` command to load the data:

Create the flight bucket:

```bash
docker exec -ti minio-mc mc mb minio-1/flight-bucket
```

**Airports:**

```bash
docker exec -ti minio-mc mc cp /data-transfer/flight-data/airports.csv minio-1/flight-bucket/raw/airports/airports.csv
```

**Plane-Data:**

```bash
docker exec -ti minio-mc mc cp /data-transfer/flight-data/plane-data.csv minio-1/flight-bucket/raw/planes/plane-data.csv
```

**Carriers:**

```bash
docker exec -ti minio-mc mc cp /data-transfer/flight-data/carriers.json minio-1/flight-bucket/raw/carriers/carriers.json
```

**Flights:**

```bash
docker exec -ti minio-mc mc cp /data-transfer/flight-data/flights-small/flights_2008_4_1.csv minio-1/flight-bucket/raw/flights/ &&
   docker exec -ti minio-mc mc cp /data-transfer/flight-data/flights-small/flights_2008_4_2.csv minio-1/flight-bucket/raw/flights/ &&
   docker exec -ti minio-mc mc cp /data-transfer/flight-data/flights-small/flights_2008_5_1.csv minio-1/flight-bucket/raw/flights/ &&
   docker exec -ti minio-mc mc cp /data-transfer/flight-data/flights-small/flights_2008_5_2.csv minio-1/flight-bucket/raw/flights/ &&
   docker exec -ti minio-mc mc cp /data-transfer/flight-data/flights-small/flights_2008_5_3.csv minio-1/flight-bucket/raw/flights/
```

## Register tables for Raw data

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

Register airports as table `airport_raw_t `

```
DROP TABLE IF EXISTS airport_raw_t;
CREATE TABLE airport_raw_t 
   (iata string
                                , airport string
                                , city string                                
                                , state string
                                , country string
                                , lat double
                                , long double)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
   "skip.header.line.count"="1"
)
LOCATION 's3a://flight-bucket/raw/airports';
```
Register flights as table `flight_raw_t `

```
DROP TABLE IF EXISTS flight_raw_t;
CREATE TABLE flight_raw_t 
   (
 	year integer,    
 	month integer,
   dayOfMonth integer,
   dayOfWeek integer,
   depTime integer,
   crsDepTime integer,
   arrTime integer,
   crsArrTime integer,
   uniqueCarrier string,
   flightNum string,
   tailNum string,
   actualElapsedTime integer,
   crsElapsedTime integer,
   airTime integer,
   arrDelay integer,
   depDelay integer,
   origin string,
   destination string,
   distance integer,
   taxiIn integer,
   taxiOut integer,
   cancelled string,
   cancellationCode string,
   diverted string,
   carrierDelay string,
   weatherDelay string,
   nasDelay string,
   securityDelay string,
   lateAircraftDelay string
   )
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
   "skip.header.line.count"="1"
)
LOCATION 's3a://flight-bucket/raw/flights';
```

## Install `dbt`

Create a virtual environment

```bash
python3 -m venv venv
source venv/bin/activate
python3 -m pip install --upgrade pip
```

Create the `requirements.txt` file (if it does not yet exist) and add the following data to install `dbt-core` and `dbt-spark`

```bash
# dbt Core 1.8
dbt-core>=1.8.0

# spark adapter
dbt-spark>=1.8.0

dbt-spark[PyHive]
```		

Install requirements into virtual environment

```bash
python3 -m pip install -r requirements.txt
	
source venv/bin/activate
```
	
Verify installation

```bash
dbt --version
```
  
which should return

```bash
(venv) (base) guido.schmutz@AMANQL7VVWVC9 dbt % dbt --version
Core:
  - installed: 1.8.7
  - latest:    1.8.7 - Up to date!

Plugins:
  - spark: 1.8.0 - Up to date!
```

You now have successfully installed `dbt-core` with `dbt-spark` on your machine.	

## Create the `dbt` project

```bash
dbt init
```



