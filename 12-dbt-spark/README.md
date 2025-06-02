# Working with `dbt` and Spark

In this workshop we will work with [dbt](https://www.getdbt.com/).

The same raw data as in the [Object Storage Workshop](../02a-minio-object-storage/README.md) will be used. We will show later how to re-upload the files, if you no longer have them available.
 
## Prepare the raw data, if no longer available

The data needed here has been uploaded in [Workshop 2 - Working with MinIO Object Storage](../02a-minio-object-storage). You can skip this section, if you still have the raw data available in MinIO. We are using the `mc` command to load the data:

Create the flight bucket:

```bash
docker exec -ti minio-mc mc mb minio-1/flight-bucket
```

**Airports:**

```bash
docker exec -ti minio-mc mc cp /data-transfer/airport-data/airports.csv minio-1/flight-bucket/raw/airports/airports.csv
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

In order to access data in HDFS or Object Storage using dbt, we have to create a table in the Hive metastore. Note that the location `s3a://flight-bucket/raw/..` points to the data we have uploaded before.

Connect to Hive Metastore CLI

```bash
docker exec -ti hive-metastore hive
```

and on the command prompt first create a new database `flight_db` 

```sql
CREATE DATABASE flight_db
LOCATION 's3a://flight-bucket/';
```

switch into that database

```sql
USE flight_db;
```

Register airports as table `airport_raw_t `

```
DROP TABLE IF EXISTS airport_raw_t;
CREATE EXTERNAL TABLE airport_raw_t 
   (id string
   , ident string
   , type string
   , name string
   , latitude_deg string
   , longitude_deg string
   , elevation_ft string
   , continent string
   , iso_country string
   , iso_region string
   , municipality string
   , scheduled_service string
   , gps_code string
   , iata_code string
   , local_code string
   , home_link string
   , wikipedia_link string
   , keywords string)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
   "skip.header.line.count" = "1",
   "separatorChar" = ","
)
STORED AS TEXTFILE
LOCATION 's3a://flight-bucket/raw/airports';
```

We use `string` as the datatype for all columns in the raw layer. We will later cast to the correct datatypes when creating the data in the prepared layer.


Register flights as table `flight_raw_t`

```
DROP TABLE IF EXISTS flight_raw_t;
CREATE EXTERNAL TABLE flight_raw_t 
   (year integer,
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
LOCATION 's3a://flight-bucket/raw/flights';
```

## Install `dbt`

Create a virtual environment

```bash
mkdir -p workspace/dbt
cd workspace/dbt
```

Install venv support if not available

```bash
sudo apt install python3.12-venv
```

now create a virtual environment

```bash
python3 -m venv venv
source venv/bin/activate
python3 -m pip install --upgrade pip
```

Create the `requirements.txt` file (if it does not yet exist) and add the following data to install `dbt-core` and `dbt-spark`

```bash
# dbt Core 1.9
dbt-core>=1.9.6

# spark adapter
dbt-spark>=1.9.1

dbt-spark[PyHive]
```		

Install requirements into virtual environment

```bash
python3 -m pip install -r requirements.txt
```
	
Verify installation

```bash
dbt --version
```
  
which should return

```bash
(venv) ubuntu@ip-172-26-6-70:~/workspace/dbt-spark$ dbt --version
WARNING:thrift.transport.sslcompat:using legacy validation callback
Core:
  - installed: 1.9.6
  - latest:    1.9.6 - Up to date!

Plugins:
  - spark: 1.9.2 - Up to date!
```

You now have successfully installed `dbt-core` with `dbt-spark` on your machine.	

## Create the `dbt` project

```bash
dbt init
```

Enter the following values:

  * **Name of project**: `spark_flight`
  * **Which database**: `1` (i.e. spark)
  * **Thrift Server Host**: `18.158.72.138`
  * **Desired authentication method**: `3` (i.e. thriftserver)
  * **Thrift Server Port**: `28118`
  * **Schema**: `flight_db`
  * **Threads**: `1`

```bash
(venv) ubuntu@ip-172-26-6-70:~/workspace/dbt$ dbt init
18:19:21  Running with dbt=1.9.6
Enter a name for your project (letters, digits, underscore): spark_flight
18:19:54
Your new dbt project "spark_flight" was created!

For more information on how to configure the profiles.yml file,
please consult the dbt documentation here:

  https://docs.getdbt.com/docs/configure-your-profile

One more thing:

Need help? Don't hesitate to reach out to us via GitHub issues or on Slack:

  https://community.getdbt.com/

Happy modeling!

18:19:54  Setting up your profile.
Which database would you like to use?
[1] spark

(Don't see the one you want? https://docs.getdbt.com/docs/available-adapters)

Enter a number: 1
WARNING:thrift.transport.sslcompat:using legacy validation callback
host (yourorg.sparkhost.com): 18.158.72.138
[1] odbc
[2] http
[3] thrift
Desired authentication method option (enter a number): 3
port [443]: 28118
schema (default schema that dbt will build objects in): flight_db
threads (1 or more) [1]: 1
18:22:11  Profile spark_flight written to /home/ubuntu/.dbt/profiles.yml using target's profile_template.yml and your supplied values. Run 'dbt debug' to validate the connection.
```

Now let's see if the dbt project is ready

```bash
cd spark_flight
dbt debug
```

And you should see an output similar to the one shown below. 

```bash
(venv) ubuntu@ip-172-26-6-70:~/workspace/dbt/spark_flight$ dbt debug
18:23:01  Running with dbt=1.9.6
18:23:01  dbt version: 1.9.6
18:23:01  python version: 3.12.3
18:23:01  python path: /home/ubuntu/workspace/dbt/venv/bin/python3
18:23:01  os info: Linux-6.8.0-1018-aws-x86_64-with-glibc2.39
WARNING:thrift.transport.sslcompat:using legacy validation callback
18:23:01  Using profiles dir at /home/ubuntu/.dbt
18:23:01  Using profiles.yml file at /home/ubuntu/.dbt/profiles.yml
18:23:01  Using dbt_project.yml file at /home/ubuntu/workspace/dbt/spark_flight/dbt_project.yml
18:23:01  adapter type: spark
18:23:01  adapter version: 1.9.2
18:23:01  Configuration:
18:23:01    profiles.yml file [OK found and valid]
18:23:01    dbt_project.yml file [OK found and valid]
18:23:01  Required dependencies:
18:23:02   - git [OK found]

18:23:02  Connection:
18:23:02    host: 18.158.72.138
18:23:02    port: 28118
18:23:02    cluster: None
18:23:02    endpoint: None
18:23:02    schema: flight
18:23:02    organization: 0
18:23:02  Registered adapter: spark=1.9.2
18:23:02    Connection test: [OK connection ok]

18:23:02  All checks passed!
```

If it shows `All checks passed!` then we are ready to work with dbt. 

We can see the directory structure created by the `init`

```bash
(venv) ubuntu@ip-172-26-6-70:~/workspace/dbt/spark_flight$ tree
.
├── README.md
├── analyses
├── dbt_project.yml
├── logs
│   └── dbt.log
├── macros
├── models
│   └── example
│       ├── my_first_dbt_model.sql
│       ├── my_second_dbt_model.sql
│       └── schema.yml
├── seeds
├── snapshots
└── tests

9 directories, 6 files
```

We won`t use the example in models, so let's remove it for now. 

```bash
rm -R models/example
```

## Create models

Let's create the folder structure underneath the `models` folder to organize the models.

```bash
mkdir -p models/flight/raw
mkdir -p models/flight/prepared
mkdir -p models/flight/refined
```

### Raw Layer

First we have to "register" the raw sources. 

```bash
nano models/flight/raw/raw-sources.yml
```

```yaml
version: 2

sources:
  - name: flight_db
    config:
      meta:
        technical_owner: PeterMuster
        data_tier: Raw
    tables:
      - name: airport_raw_t

      - name: flight_raw_t
```

The tables we register here have to match the ones we created above in Hive Metastore on our raw objects in MinIO.

### Prepared Layer

```bash
nano models/flight/prepared/airport_prep_t.sql
```

```sql
WITH airport_prep_t AS (
   SELECT 
        CAST (id AS INT) as id, 
        ident,
        type,
        name,
        CAST (latitude_deg AS DOUBLE) as latitude_degree,
        CAST (longitude_deg AS DOUBLE) as longitude_degree,
        CAST (elevation_ft AS INT) as elevation_feet,
        continent,
        iso_country,
        iso_region,
        municipality,
        scheduled_service,
        gps_code,
        iata_code,
        local_code,
        home_link,
        wikipedia_link,
        keywords
    FROM {{ source('flight_db', 'airport_raw_t') }}
) SELECT * 
FROM airport_prep_t
```

```bash
nano models/flight/prepared/flight_prep_t.sql
```


```sql
WITH flight_prep_t AS (
   SELECT year, 
        month,
        dayOfMonth,
        dayOfWeek,
        depTime, 
        crsDepTime, 
        arrTime,
        crsArrTime, 
        uniqueCarrier, 
        flightNum, 
        tailNum, 
        actualElapsedTime,
        crsElapsedTime, 
        airTime, 
        arrDelay,
        depDelay,
        origin, 
        destination, 
        distance, 
        taxiIn, 
        taxiOut, 
        cancelled, 
        cancellationCode, 
        diverted,
        carrierDelay, 
        weatherDelay, 
        nasDelay, 
        securityDelay, 
        lateAircraftDelay 
    from {{ source('flight_db', 'flight_raw_t') }} 
)select * 
from flight_prep_t
```

Now let's run dbt for the two prepared layer objects

```bash
dbt run
```

and you should see a result similar to the one below

```
(venv) ubuntu@ip-172-26-6-70:~/workspace/dbt/spark_flight$ dbt run
19:02:29  Running with dbt=1.9.6
WARNING:thrift.transport.sslcompat:using legacy validation callback
19:02:29  Registered adapter: spark=1.9.2
19:02:29  [WARNING]: Configuration paths exist in your dbt_project.yml file which do not apply to any resources.
There are 1 unused configuration paths:
- models.spark_flight.example
19:02:29  Found 2 models, 2 sources, 473 macros
19:02:29
19:02:29  Concurrency: 1 threads (target='dev')
19:02:29
19:02:30  1 of 2 START sql view model flight_db.airport_prep_t ........................... [RUN]
19:02:30  1 of 2 OK created sql view model flight_db.airport_prep_t ...................... [OK in 0.45s]
19:02:30  2 of 2 START sql view model flight_db.flight_prep_t ............................ [RUN]
19:02:30  2 of 2 OK created sql view model flight_db.flight_prep_t ....................... [OK in 0.36s]
19:02:31
19:02:31  Finished running 2 view models in 0 hours 0 minutes and 1.19 seconds (1.19s).
19:02:31
19:02:31  Completed successfully
19:02:31
19:02:31  Done. PASS=2 WARN=0 ERROR=0 SKIP=0 TOTAL=2
```

The two objects in the prepared layer have been created as views (as shown by `view model`).

### Refined Layer

```bash
nano models/flight/refined/flight_ref_t.sql
```


```sql
WITH flight_ref_t as (
    SELECT ao.name AS origin_airport
            , ao.type AS origin_type
            , ao.municipality AS origin_municipality
            , ad.name AS destination_airport
            , ad.type AS destination_type
            , ad.municipality AS destination_municipality
            , f.*
    FROM {{ref ('flight_prep_t')}}  AS f
    LEFT JOIN {{ref ('airport_prep_t')}} AS ao
    ON (f.origin = ao.iata_code)
    LEFT JOIN {{ref ('airport_prep_t')}} AS ad
    ON (f.destination = ad.iata_code)
) SELECT * 
FROM flight_ref_t
```

```bash
nano models/flight/refined/flight_delays_ref_t.sql
```

```sql
WITH flight_delays_ref_t AS (
    SELECT year, month, dayOfMonth, dayOfWeek, arrDelay, origin, destination,
        CASE
            WHEN arrDelay > 360 THEN 'Very Long Delays'
            WHEN arrDelay > 120 AND arrDelay < 360 THEN 'Long Delays'
            WHEN arrDelay > 60 AND arrDelay < 120 THEN 'Short Delays'
            WHEN arrDelay > 0 and arrDelay < 60 THEN 'Tolerable Delays'
            WHEN arrDelay = 0 THEN 'No Delays'
            ELSE 'Early'
        END AS flight_delays
            FROM {{ref ('flight_prep_t')}}
) SELECT * 
FROM flight_delays_ref_t
```

Let's rerun `dbt run` for the two new refined objects:

```bash
(venv) ubuntu@ip-172-26-6-70:~/workspace/dbt/spark_flight$ dbt run
19:13:12  Running with dbt=1.9.6
WARNING:thrift.transport.sslcompat:using legacy validation callback
19:13:13  Registered adapter: spark=1.9.2
19:13:13  Unable to do partial parsing because a project config has changed
19:13:15  [WARNING]: Configuration paths exist in your dbt_project.yml file which do not apply to any resources.
There are 1 unused configuration paths:
- models.spark_flight.example
19:13:15  Found 4 models, 2 sources, 473 macros
19:13:15
19:13:15  Concurrency: 1 threads (target='dev')
19:13:15
19:13:15  1 of 4 START sql view model flight_db.airport_prep_t ........................... [RUN]
19:13:15  1 of 4 OK created sql view model flight_db.airport_prep_t ...................... [OK in 0.38s]
19:13:16  2 of 4 START sql view model flight_db.flight_prep_t ............................ [RUN]
19:13:16  2 of 4 OK created sql view model flight_db.flight_prep_t ....................... [OK in 0.29s]
19:13:16  3 of 4 START sql view model flight_db.flight_delays_ref_t ...................... [RUN]
19:13:16  3 of 4 OK created sql view model flight_db.flight_delays_ref_t ................. [OK in 0.36s]
19:13:16  4 of 4 START sql view model flight_db.flight_ref_t ............................. [RUN]
19:13:17  4 of 4 OK created sql view model flight_db.flight_ref_t ........................ [OK in 0.42s]
19:13:17
19:13:17  Finished running 4 view models in 0 hours 0 minutes and 1.91 seconds (1.91s).
19:13:17
19:13:17  Completed successfully
19:13:17
19:13:17  Done. PASS=4 WARN=0 ERROR=0 SKIP=0 TOTAL=4
(venv) ubuntu@ip-172-26-6-70:~/workspace/dbt/spark_flight$
```

We can see that these are also created as Views (`view model`).

You can crosscheck that by using DBeaver and connecting to the Spark Thriftserver, as demonstrated in [Workshop 4 - Data Reading and Writing using DataFrames](../04-spark-dataframe/README.md).

We can also change the materialization to table. This can be configured in `dbt_project.yml`.

```bash
nano dbt_project.yml
```

Navigate to the end and remove the entry for the `example` model

```
models:
  spark_flight:
    # Config indicated by + and applies to all files under models/example/
    example:
      +materialized: view
```

by an entry for our `flight` model with the materialization as `table`

```
models:
  spark_flight:
    # Config indicated by + and applies to all files under models/example/
    flight:
      +materialized: table
```

Now re-run dbt

`dbt run` 

and the views should get replaced by tables, as shown in the log

```bash
(venv) ubuntu@ip-172-26-6-70:~/workspace/dbt/spark_flight$ dbt run
19:21:42  Running with dbt=1.9.6
WARNING:thrift.transport.sslcompat:using legacy validation callback
19:21:42  Registered adapter: spark=1.9.2
19:21:43  Unable to do partial parsing because a project config has changed
19:21:44  Found 4 models, 2 sources, 473 macros
19:21:44
19:21:44  Concurrency: 1 threads (target='dev')
19:21:44
19:21:44  1 of 4 START sql table model flight_db.airport_prep_t .......................... [RUN]
19:21:47  1 of 4 OK created sql table model flight_db.airport_prep_t ..................... [OK in 2.98s]
19:21:47  2 of 4 START sql table model flight_db.flight_prep_t ........................... [RUN]
19:21:50  2 of 4 OK created sql table model flight_db.flight_prep_t ...................... [OK in 2.58s]
19:21:50  3 of 4 START sql table model flight_db.flight_delays_ref_t ..................... [RUN]
19:21:52  3 of 4 OK created sql table model flight_db.flight_delays_ref_t ................ [OK in 1.90s]
19:21:52  4 of 4 START sql table model flight_db.flight_ref_t ............................ [RUN]
19:21:56  4 of 4 OK created sql table model flight_db.flight_ref_t ....................... [OK in 3.88s]
19:21:56
19:21:56  Finished running 4 table models in 0 hours 0 minutes and 11.69 seconds (11.69s).
19:21:56
19:21:56  Completed successfully
19:21:56
19:21:56  Done. PASS=4 WARN=0 ERROR=0 SKIP=0 TOTAL=4
(venv) ubuntu@ip-172-26-6-70:~/workspace/dbt/spark_flight$
```

## Query the results from Trino





