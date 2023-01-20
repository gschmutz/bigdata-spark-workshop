# Working with Trino

For this workshop you have to start a platform using the `minio` flavour in the init script.

## Introduction

[Trino](https://trino.io/) (previously know as PrestoSQL) Trino is a distributed SQL query engine designed to query large data sets distributed over one or more heterogeneous data sources. Trino can natively query data in Hadoop, S3, Cassandra, MySQL, and many others, without the need for complex and error-prone processes for copying the data to a proprietary storage system. You can access data from multiple systems within a single query. For example, join historic log data stored in S3 with real-time customer data stored in MySQL. This is called **query federation**.

In this workshop we are using Trino to access the data we have available in the Object Storage. 

We assume that the **Data platform** described [here](../01-environment) is running using the `minio` flavour. 

The docker image we use for the Trino container is from [Starburst Data](https://www.starburstdata.com/), the company offering an Enterprise version of Trino. 

## Prepare the data, if no longer available

The data needed here has been uploaded in workshop 3 - [Working with MinIO Object Storage](03-object-storage). You can skip this section, if you still have the data available in MinIO. We show both `s3cmd` and the `mc` version of the commands:

Create the flight bucket:

```bash
docker exec -ti awscli s3cmd mb s3://flight-bucket
```

or with `mc`
 
```bash
docker exec -ti minio-mc mc mb minio-1/flight-bucket
```

**Airports:**

```bash



## Using Trino to access Object Storage

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

### Query Airport Table from Trino

Next let's query the data from Trino. Connect to the Trino CLI from a terminal window

```bash
docker exec -it trino-cli trino --server trino-1:8080
```

Now on the Trino command prompt, switch to the right database. 

```sql
use minio.flight_db;
```

Let's see that there is one table available:

```sql
show tables;
```

We can see the `airport_t` table we created in the Hive Metastore before

```sql
trino:default> show tables;
     Table
---------------
 airport_t
(1 row)
```

We can use the `DESCRIBE` command to see the structure of the table:

```sql
DESCRIBE minio.flight_db.airport_t;
```

and you should get the following result

```sql
trino:flight_db> DESCRIBE minio.flight_db.airport_t;
 Column  |  Type   | Extra | Comment
---------+---------+-------+---------
 iata    | varchar |       |
 airport | varchar |       |
 city    | varchar |       |
 state   | varchar |       |
 country | varchar |       |
 lat     | double  |       |
 long    | double  |       |
```

We can also leave out the `minio.fligth_db` qualifier, because it is the current database.

```sql
DESCRIBE airport_t;
```

We can query the table from the current database

```sql
SELECT * FROM airport_t;
```

And of course we can execute the same query with a fully qualified table, including the database:

```sql
SELECT * 
FROM minio.flight_db.airport_t;
```

We will see later, that this becomes handy if we are querying from multiple, different databases.

We can use everything SQL provides, so for example let's see the airports in state California ('CA')

```sql
SELECT * FROM airport_t 
WHERE state = 'CA' AND country = 'USA';
```

if you just want to know how many, then let's use `COUNT(*)` 

```sql
SELECT count(*) FROM airport_t 
WHERE state = 'CA' AND country = 'USA';
```

Exit from the Trino CLI

```sql
exit;
```

Trino also provides the [Trino UI](http://dataplatform:28081/ui) for monitoring the queries executed on the trino server. Use the user `admin` on the login page.

With the query on the airports data being successful, let's also create the table for the flights data.

### Create Flights Table in Hive Metastore

In a terminal window, connect again to Hive Metastore CLI

```bash
docker exec -ti hive-metastore hive
```

change to the database created before

```sql
USE flight_db;
```

and create the `flight_t` table. Because it is a partitioned table using the parquet format (check the previous workshop for how it has been stored), we have to use the `PARTITIONED BY` and `STORED AS` clause. 

```sql
CREATE EXTERNAL TABLE flights_t ( dayOfMonth integer
                             , dayOfWeek integer
                             , depTime integer
                             , crsDepTime integer
                             , arrTime integer
                             , crsArrTime integer
                             , uniqueCarrier string
                             , flightNum string
                             , tailNum string
                             , actualElapsedTime integer
                             , crsElapsedTime integer
                             , airTime integer
                             , arrDelay integer
                             , depDelay integer
                             , origin string
                             , destination string
                             , distance integer) 
PARTITIONED BY (year integer, month integer)
STORED AS parquet
LOCATION 's3a://flight-bucket/refined/flights';
```

Before we can query the table using Trino, we also have to repair the table, so that it recognises the partitions underneath it. You have to repeat that statement whenever you add new data to the location in Object Store / HDFS.

```sql
MSCK REPAIR TABLE flights_t;
```

Now we are ready to query it. 

Exit from the Hive Metastore CLI 

```
exit;
```

### Query Flights Table from Trino

In a terminal window, again connect to the Trino CLI using

```bash
docker exec -it trino-cli trino --server trino-1:8080
```

and switch to the correct database

```sql
use minio.flight_db;
```

Let's see that the newly created `flight_s` table is also available:

```sql
show tables;
```

So let's see the data

```sql
SELECT * FROM flights_t;
```

We can see the same data as when doing the Spark DataFrame workshop. 

Of course we can't just use a `SELECT * ...` but also do analytical queries. 

Let's see how many flights we have between an origin and a destination

```sql
SELECT origin, destination, count(*)
FROM flights_t
GROUP BY origin, destination;
```

and the same for just the month of April in 2008:

```sql
SELECT origin, destination, count(*)
FROM flights_t
WHERE year = 2008 and month = 04
GROUP BY origin, destination;
```

Of course there is much more. Consult the Trino documentation to learn more about [Trino in general](https://trino.io/docs/current/) as well as the available [Functions and Operators](https://trino.io/docs/current/functions.html).

Of course you can also join the `flights_t` table with the `airports_t` table to enrich it, similar than we have done it in the Spark DataFrame workshop. We leave that as an exercise and show a different way of joining data in the next section.

## Using Trino to access a Relational Database

In this section we create the airports data as a Postgresql table. Let's assume by that, that the Airports data has not been loaded into Object Storage and that the Postgresql database is the leading system for airport data. 

### Create the table in Postgresql RDBMS

Connect to Postgresql

```bash
docker exec -ti postgresql psql -d postgres -U postgres
```

Create a database and the table for the airport data using a different name  `pg_airport_t` to distinguish it to the one in Minio. 

```sql
CREATE SCHEMA flight_data;

DROP TABLE IF EXISTS flight_data.pg_airport_t;

CREATE TABLE flight_data.pg_airport_t
(
  iata character varying(50) NOT NULL,
  airport character varying(50),
  city character varying(50),
  state character varying(50),
  country character varying(50),
  lat float,
  long float,
  CONSTRAINT airport_pk PRIMARY KEY (iata)
);
```

Finally let's import the data from the data-transfer folder. 

```sql
COPY flight_data.pg_airport_t(iata,airport,city,state,country,lat,long) 
FROM '/data-transfer/flight-data/airports.csv' DELIMITER ',' CSV HEADER;
```

### Query Table from Trino

Next let's query the data from Trino. Once more connect to the Trino CLI using

```bash
docker exec -it trino-cli trino --server trino-1:8080
```

Now on the Trino command prompt, switch to the database representing the Postgresql. 

```sql
use postgresql.flight_data;
```

Let's see that there is one table available:

```sql
show tables;
```

We can see the `pg_airport_t` table we created in the Postgresql RDBMS 

```sql
trino:default> show tables;
     Table
---------------
 pg_airport_t
(1 row)
```

check that you can query the data, now from Postgresql RDBMS. 

```sql
SELECT * FROM pg_airport_t;
```

Of course you can also do analytical queries:

```sql
SELECT country, count(*)
FROM pg_airport_t
GROUP BY country;
```

## Query Federation using Trino

With the `pg_airport_t` table available in the Postgresql and the `flights_t` available in the Object Store through Hive Metastore, we can finally use Trino's query federation capabilities to join the two tables using a `SELECT ... FROM ... LEFT JOIN` statement: 

```sql
SELECT ao.airport, ao.city, ad.airport, ad.city, f.*
FROM minio.flight_db.flights_t  AS f
LEFT JOIN postgresql.flight_data.pg_airport_t AS ao
ON (f.origin = ao.iata)
LEFT JOIN postgresql.flight_data.pg_airport_t AS ad
ON (f.destination = ad.iata);
```


Trino supports among the Hive and PostgreSQL (RDBMS) we have seen so far many more data sources. Find [here the list of connectors](https://trino.io/docs/current/connector.html) Trino provides to connect to the various data sources.

