# Working with Trino

For this workshop you have to start a platform using the `minio` flavour in the init script.

## Introduction

[Trino](https://trino.io/) (previously know as PrestoSQL) is a distributed SQL query engine designed to query large data sets distributed over one or more heterogeneous data sources. Trino can natively query data in Hadoop, S3, Cassandra, MySQL, and many others, without the need for complex and error-prone processes for copying the data to a proprietary storage system. You can access data from multiple systems within a single query. For example, join historic log data stored in S3 with real-time customer data stored in MySQL. This is called **query federation**.

In this workshop we are using Trino to access the data we have available in the Object Storage. 

We assume that the **Data platform** described [here](../01-environment) is running using the `minio` flavour. 

The docker image we use for the Trino container is from [Starburst Data](https://www.starburstdata.com/), the company offering an Enterprise version of Trino. 

## Prepare the data, if no longer available

The data needed here has been uploaded in [Workshop 4 - Data Reading and Writing using DataFrames](../04-spark-dataframe). You can skip this section, if you still have the data available in MinIO.

Create the flight bucket:
 
```bash
docker exec -ti minio-mc mc mb minio-1/flight-bucket
```

and then copy the refined data 

```bash
docker exec -ti minio-mc mc cp --recursive /data-transfer/flight-data/refined minio-1/flight-bucket/
```

## Using Trino to access Object Storage

In order for us to use Trino with Object Storage, we first have to create the necessary tables in Hive Metastore. Trino is using the Hive Metastore for a place to get the necessary metadata about the data itself (i.e. the table view on the raw data in object storage)

### Create Airport Table in Hive Metastore

In order to access data in Object Storage using Trino, we have to create a table in the Hive metastore. Note that the location `s3a://flight-bucket/refined/..` points to the data we have created in the [previous workshop](../04-spark-dataframe)/uploaded before.

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

and create a table `airport_t`:

```
CREATE EXTERNAL TABLE airport_t (id int
                                , ident string
                                , type string
                                , name string
                                , latitude_deg double
                                , longitude_deg double
                                , elevation_ft int                                , continent string                                , iso_country string
                                , iso_region string                                , municipality string                                , scheduled_service string                                , gps_code string
                                , iata_code string
                                , local_code string
                                , home_link string                                , wikipedia_link string
                                , keywords string
                                )
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
docker exec -it trino-1 trino --server trino-1:8080
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
      Column       |  Type   | Extra | Comment 
-------------------+---------+-------+---------
 id                | integer |       |         
 ident             | varchar |       |         
 type              | varchar |       |         
 name              | varchar |       |         
 latitude_deg      | double  |       |         
 longitude_deg     | double  |       |         
 elevation_ft      | integer |       |         
 continent         | varchar |       |         
 iso_country       | varchar |       |         
 iso_region        | varchar |       |         
 municipality      | varchar |       |         
 scheduled_service | varchar |       |         
 gps_code          | varchar |       |         
 iata_code         | varchar |       |         
 local_code        | varchar |       |         
 home_link         | varchar |       |         
 wikipedia_link    | varchar |       |         
 keywords          | varchar |       |         
(18 rows)

Query 20250525_133931_00004_83kbj, FINISHED, 1 node
Splits: 5 total, 5 done (100.00%)
0.64 [18 rows, 1.12KiB] [28 rows/s, 1.76KiB/s]
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
WHERE iso_region = 'US-CA' AND iso_country = 'US';
```

if you just want to know how many, then let's use `COUNT(*)` 

```sql
SELECT count(*) FROM airport_t 
WHERE iso_region = 'US-CA' AND iso_country = 'US';
```

and you should see a result similar to that

```sql
trino:flight_db> SELECT count(*) FROM airport_t 
              -> WHERE iso_region = 'US-CA' AND iso_country = 'US';
 _col0 
-------
  2364 
(1 row)

Query 20250525_134202_00014_83kbj, FINISHED, 1 node
Splits: 5 total, 5 done (100.00%)
0.93 [81.2K rows, 23.7MiB] [87K rows/s, 25.4MiB/s]
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

Before we can query the table using Trino, we also have to repair the table, so that it recognises the partitions underneath it. You have to repeat that statement whenever you add new data to the location in Object Store.

```sql
MSCK REPAIR TABLE flights_t;
```

Now we are ready to query it. 

Exit from the Hive Metastore CLI 

```sql
exit;
```

### Query Flights Table from Trino

In a terminal window, again connect to the Trino CLI using

```bash
docker exec -it trino-1 trino --server trino-1:8080
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


## Using Trino built-in Functions

Trino supports a lot of built-in SQL functions and opperators. They allow you to implement complex capabilities and behavior of the queries executed by Trino operating on the underlying data sources.

You can find the list of supported functions in the Trino documention:

  * [List of functions and operators](https://trino.io/docs/current/functions/list.html)
  * [List of functions by topic](https://trino.io/docs/current/functions/list-by-topic.html)

Alternativily you can use `SHOW FUNCTIONS` to list the available functions in the CLI

```sql
SHOW FUNCTIONS;
```

and you get a paged list of functions, similar to shown below

```sql
            Function             |         Return Type          |                                 Argument Types                                 | Function Type | Deterministic |            >
---------------------------------+------------------------------+--------------------------------------------------------------------------------+---------------+---------------+------------>
 abs                             | bigint                       | bigint                                                                         | scalar        | true          | Absolute va>
 abs                             | decimal(p,s)                 | decimal(p,s)                                                                   | scalar        | true          | Absolute va>
 abs                             | double                       | double                                                                         | scalar        | true          | Absolute va>
 abs                             | integer                      | integer                                                                        | scalar        | true          | Absolute va>
 abs                             | real                         | real                                                                           | scalar        | true          | Absolute va>
 abs                             | smallint                     | smallint                                                                       | scalar        | true          | Absolute va>
 abs                             | tinyint                      | tinyint                                                                        | scalar        | true          | Absolute va>
 acos                            | double                       | double                                                                         | scalar        | true          | Arc cosine >
 all_match                       | boolean                      | array(t), function(t,boolean)                                                  | scalar        | true          | Returns tru>
 any_match                       | boolean                      | array(t), function(t,boolean)                                                  | scalar        | true          | Returns tru>
 any_value                       | t                            | t                                                                              | aggregate     | true          | Return an a>
 any_value                       | t                            | t                                                                              | aggregate     | true          | Return an a>
 approx_distinct                 | bigint                       | boolean                                                                        | aggregate     | true          |            >
 approx_distinct                 | bigint                       | boolean, double                                                                | aggregate     | true          |            >
 approx_distinct                 | bigint                       | t                                                                              | aggregate     | true          |            >
 approx_distinct                 | bigint                       | t, double                                                                      | aggregate     | true          |            >
 approx_distinct                 | bigint                       | unknown                                                                        | aggregate     | true          |            >
 approx_distinct                 | bigint                       | unknown, double                                                                | aggregate     | true          |            >
 approx_most_frequent            | map(bigint,bigint)           | bigint, bigint, bigint                                                         | aggregate     | true          |            >
 approx_most_frequent            | map(varchar,bigint)          | bigint, varchar, bigint                                                        | aggregate     | true          |            >
 approx_percentile               | array(bigint)                | bigint, array(double)                                                          | aggregate     | true          |            >
 approx_percentile               | array(bigint)                | bigint, double, array(double)                                                  | aggregate     | true          |            >
 approx_percentile               | array(double)                | double, array(double)                                                          | aggregate     | true          |            >
 approx_percentile               | array(double)                | double, double, array(double)                                                  | aggregate     | true          |            >
 approx_percentile               | array(real)                  | real, array(double)                                                            | aggregate     | true          |            >
 approx_percentile               | array(real)                  | real, double, array(double)                                                    | aggregate     | true          |            >
 approx_percentile               | bigint                       | bigint, double                                                                 | aggregate     | true          |            >
 approx_percentile               | bigint                       | bigint, double, double                                                         | aggregate     | true          |            >
 approx_percentile               | bigint                       | bigint, double, double, double                                                 | aggregate     | true          |            >
 approx_percentile               | double                       | double, double                                                                 | aggregate     | true          |            >
 approx_percentile               | double                       | double, double, double                                                         | aggregate     | true          |            >
 approx_percentile               | double                       | double, double, double, double                                                 | aggregate     | true          |            >
 approx_percentile               | real                         | real, double                                                                   | aggregate     | true          |            >
 approx_percentile               | real                         | real, double, double                                                           | aggregate     | true          |            >
 approx_percentile               | real                         | real, double, double, double                                                   | aggregate     | true          |            >
 approx_set                      | hyperloglog                  | bigint                                                                         | aggregate     | true          |            >
 approx_set                      | hyperloglog                  | double                                                                         | aggregate     | true          |            >
 approx_set                      | hyperloglog                  | varchar(x)                                                                     | aggregate     | true          |            >
 arbitrary                       | t                            | t                                                                              | aggregate     | true          | Return an a>
 arbitrary                       | t                            | t                                                                              | aggregate     | true          | Return an a>
 array_agg                       | array(t)                     | t                                                                              | aggregate     | true          | return an a>
 array_distinct                  | array(e)                     | array(e)                                                                       | scalar        | true          | Remove dupl>
 array_except                    | array(e)                     | array(e), array(e)                                                             | scalar        | true          | Returns an >
 array_histogram                 | map(t,bigint)                | array(t)                                                                       | scalar        | true          | Return a ma>
:
```

you can also use the `LIKE` clause to only show certain functions, e.g. the ones starting with `array`

```sql
SHOW FUNCTIONS LIKE 'array%';
```

and you get the following result

```
trino:flight_db> SHOW FUNCTIONS LIKE 'array%';
    Function     |  Return Type  |         Argument Types          | Function Type | Deterministic |                                              Description                                 >
-----------------+---------------+---------------------------------+---------------+---------------+------------------------------------------------------------------------------------------>
 array_agg       | array(t)      | t                               | aggregate     | true          | return an array of values                                                                >
 array_distinct  | array(e)      | array(e)                        | scalar        | true          | Remove duplicate values from the given array                                             >
 array_except    | array(e)      | array(e), array(e)              | scalar        | true          | Returns an array of elements that are in the first array but not the second, without dupl>
 array_histogram | map(t,bigint) | array(t)                        | scalar        | true          | Return a map containing the counts of the elements in the array                          >
 array_intersect | array(e)      | array(e), array(e)              | scalar        | true          | Intersects elements of the two given arrays                                              >
 array_join      | varchar       | array(e), varchar               | scalar        | true          | Concatenates the elements of the given array using a delimiter and an optional string to >
 array_join      | varchar       | array(e), varchar, varchar      | scalar        | true          | Concatenates the elements of the given array using a delimiter and an optional string to >
 array_max       | t             | array(t)                        | scalar        | true          | Get maximum value of array                                                               >
 array_min       | t             | array(t)                        | scalar        | true          | Get minimum value of array                                                               >
 array_position  | bigint        | array(t), t                     | scalar        | true          | Returns the position of the first occurrence of the given value in array (or 0 if not fou>
 array_remove    | array(e)      | array(e), e                     | scalar        | true          | Remove specified values from the given array                                             >
 array_sort      | array(e)      | array(e)                        | scalar        | true          | Sorts the given array in ascending order according to the natural ordering of its element>
 array_sort      | array(t)      | array(t), function(t,t,integer) | scalar        | true          | Sorts the given array with a lambda comparator.                                          >
 array_union     | array(e)      | array(e), array(e)              | scalar        | true          | Union elements of the two given arrays                                                   >
 arrays_overlap  | boolean       | array(e), array(e)              | scalar        | true          | Returns true if arrays have common elements                                              >
(15 rows)
```

Using the `CASE` expression from the [Conditional expression](https://trino.io/docs/current/functions/conditional.html) category, we can recreate the same statemen we have seen with Spark SQL in [Workshop 04 - Data Reading and Writing using DataFrames](../04-spark-dataframe). Because it's standard SQL, we can just copy/paste and adapt the table name to use `flights_t` table

```sql
SELECT arrDelay, origin, destination,
    CASE
         WHEN arrDelay > 360 THEN 'Very Long Delays'
         WHEN arrDelay > 120 AND arrDelay < 360 THEN 'Long Delays'
         WHEN arrDelay > 60 AND arrDelay < 120 THEN 'Short Delays'
         WHEN arrDelay > 0 and arrDelay < 60 THEN 'Tolerable Delays'
         WHEN arrDelay = 0 THEN 'No Delays'
         ELSE 'Early'
    END AS flight_delay
FROM flights_t;
```         

Let's see in another example, how to use some the [Geospational functions](https://trino.io/docs/current/functions/geospatial.html) on the `airport_t` table. 

To calculate the distance between two airports, e.g. between New Jork (JFK) and San Francisco (SFO), we can use the following statement

```sql
SELECT orig.name
, 	orig.latitude_deg
, 	orig.longitude_deg
, 	dest.name
, 	dest.latitude_deg
, 	dest.longitude_deg
, 	ST_Distance(to_spherical_geography(ST_Point(orig.longitude_deg, orig.latitude_deg)), to_spherical_geography(ST_Point(dest.longitude_deg, dest.latitude_deg))) / 1000 AS distance_km
FROM airport_t   AS orig
JOIN airport_t  AS dest
ON (orig.iata_code = 'SFO' AND dest.iata_code = 'JFK');
```

## Using Trino User-defined Functions (UDF)

Instead of classifying the delays in SQL using the CASE expression as shown before, we can also make the bucket creation more reusable by creating a user-defined function (UDF). UDFs are scalar functions that return a single output value, similar to built-in functions, we seen above.

User defined functions can either be written in Java/Python or using the SQL routine language. We will see an example with SQL routing language first, followed by an example using Python. Java is a bit more  complicated and you have to [create a plugin](https://trino.io/docs/current/develop/functions.html), which is not covered in this workshop.

A UDF can be declared as an [inline UDF](https://trino.io/docs/current/udf/introduction.html#udf-inline) to be used in the current query, or declared as a [catalog UDF](https://trino.io/docs/current/udf/introduction.html#udf-catalog) to be used in any future query, if the connector used for the catalog supports UDF storage. Our `minio` catalog, which is using the `Hive Connector`, supports that. 

### SQL user-defined functions

A [SQL user-defined function](https://trino.io/docs/current/udf/sql.html), also known as SQL routine, is a user-defined function that uses the SQL routine language and statements for the definition of the function.

#### Inline UDF `classify_delay`

Let's first see how to create an inline UDF calcuating the delays. To test it we can just call it in a `SELECT` without reading from a table.

```sql
WITH 
  FUNCTION classify_delay(delay int) 
    RETURNS varchar
	 RETURN CASE
		         WHEN delay > 360 THEN 'Very Long Delays'
		         WHEN delay > 120 AND delay < 360 THEN 'Long Delays'
		         WHEN delay > 60 AND delay < 120 THEN 'Short Delays'
		         WHEN delay > 0 and delay < 60 THEN 'Tolerable Delays'
		         WHEN delay = 0 THEN 'No Delays'
		         ELSE 'Early'
           END
    
SELECT classify_delay(100); 
```

And we can see that the value `100` is in the bucket `Short Delays`

```sql
trino:flight_db> WITH 
              ->   FUNCTION classify_delay(delay int) 
              ->     RETURNS varchar
              ->     RETURN CASE
              ->                 WHEN delay > 360 THEN 'Very Long Delays'
              ->                 WHEN delay > 120 AND delay < 360 THEN 'Long Delays'
              ->                 WHEN delay > 60 AND delay < 120 THEN 'Short Delays'
              ->                 WHEN delay > 0 and delay < 60 THEN 'Tolerable Delays'
              ->                 WHEN delay = 0 THEN 'No Delays'
              ->                 ELSE 'Early'
              ->            END
              ->     
              -> SELECT classify_delay(100); 
    _col0     
--------------
 Short Delays 
(1 row)

Query 20250525_163740_00137_83kbj, FINISHED, 1 node
Splits: 1 total, 1 done (100.00%)
0.04 [0 rows, 0B] [0 rows/s, 0B/s]
```

#### Catalog UDF `minio.flight_db.classify_delay`

Let's create the same function as a catalog UDF using the SQL routine language

```sql
CREATE OR REPLACE FUNCTION minio.flight_db.classify_delay(delay int) 
  RETURNS varchar
  BEGIN
	 RETURN CASE
		         WHEN delay > 360 THEN 'Very Long Delays'
		         WHEN delay > 120 AND delay < 360 THEN 'Long Delays'
		         WHEN delay > 60 AND delay < 120 THEN 'Short Delays'
		         WHEN delay > 0 and delay < 60 THEN 'Tolerable Delays'
		         WHEN delay = 0 THEN 'No Delays'
		         ELSE 'Early'
           END;
  END;
```

To test it we can also call it in a `SELECT` without reading from a table.

```sql
SELECT minio.flight_db.classify_delay(100);
```

And we can see that the value `100` is in the bucket `Short Delays`

```sql
trino:flight_db> SELECT minio.flight_db.classify_delay(100);
    _col0     
--------------
 Short Delays 
(1 row)

Query 20250525_154104_00086_83kbj, FINISHED, 1 node
Splits: 1 total, 1 done (100.00%)
0.21 [0 rows, 0B] [0 rows/s, 0B/s]
```

Now let's change the statement from before to use the function instead of the CASE expression

```sql
SELECT arrDelay, origin, destination, minio.flight_db.classify_delay(arrDelay) AS flight_delay
FROM flights_t;
```

We can also adpapt the other statement we have used with Spark SQL in [Workshop 04 - Data Reading and Writing using DataFrames](../04-spark-dataframe), which groups all the flights by the `flight_delay` bucket and returns the number of flights for each bucket

```sql
SELECT year, month, flight_delay, count(*) AS count
FROM (
  SELECT year, month, destination, minio.flight_db.classify_delay(arrDelay) AS flight_delay
  FROM flights_t
)
GROUP BY year, month, flight_delay;
```

### Python user-defined functions

A Python user-defined function is a user-defined function that uses the Python programming language and statements for the definition of the function.

#### Inline UDF `python_classify_delay`

Let's first also see how to create an inline UDF calcuating the delays in python. To test it we can just call it in a `SELECT` without reading from a table.

```sql
WITH
  FUNCTION python_classify_delay(delay int)
    RETURNS varchar
    LANGUAGE PYTHON
    WITH (handler = 'classify_delay')
    AS $$
    def classify_delay(delay):
      if delay > 360:
        return 'Very Long Delays'
      elif 120 < delay <= 360:
        return 'Long Delays'
      elif 60 < delay <= 120:
        return 'Short Delays'
      elif 0 < delay <= 60:
        return 'Tolerable Delays'
      elif delay == 0:
        return 'No Delays'
      else:
        return 'Early'
    $$
SELECT python_classify_delay(100);    
```

#### Catalog UDF `minio.flight_db.python_classify_delay`

Let's create the same function as a catalog UDF using the SQL routine language

```sql
CREATE OR REPLACE FUNCTION minio.flight_db.python_classify_delay(delay int) 
  RETURNS varchar
  LANGUAGE PYTHON
  WITH (handler = 'classify_delay')
  AS $$
  def classify_delay(delay):
    if delay > 360:
      return 'Very Long Delays'
    elif 120 < delay <= 360:
      return 'Long Delays'
    elif 60 < delay <= 120:
      return 'Short Delays'
    elif 0 < delay <= 60:
      return 'Tolerable Delays'
    elif delay == 0:
      return 'No Delays'
    else:
      return 'Early'
    $$;
```

To test it we can also call it in a `SELECT` without reading from a table.

```sql
SELECT minio.flight_db.python_classify_delay(100);
```

We can now of course use it in the same way as we have used the SQL user-defined function before.

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
	id int
	, ident character varying(50)
	, type character varying(50)
   , name character varying(200)
   , latitude_deg float
   , longitude_deg float
   , elevation_ft int
   , continent character varying(50)
   , iso_country character varying(50)
   , iso_region character varying(50)
   , municipality character varying(100)
   , scheduled_service character varying(50)
   , gps_code character varying(50)
   , iata_code character varying(50)
   , local_code character varying(50)
   , home_link character varying(200)
   , wikipedia_link character varying(200)
   , keywords character varying(1000)
  , CONSTRAINT airport_pk PRIMARY KEY (id)
);
```

Finally let's import the data from the data-transfer folder. 

```sql
COPY flight_data.pg_airport_t(id, ident, type, name, latitude_deg, longitude_deg, elevation_ft, continent, iso_country, iso_region, municipality, scheduled_service, gps_code, iata_code, local_code, home_link, wikipedia_link, keywords) 
FROM '/data-transfer/airports-data/airports.csv' DELIMITER ',' CSV HEADER;
```

### Query Table from Trino

Next let's query the data from Trino. Once more connect to the Trino CLI using

```bash
docker exec -it trino-1 trino --server trino-1:8080
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
SELECT iso_country, count(*)
FROM pg_airport_t
GROUP BY iso_country;
```

## Query Federation using Trino

With the `pg_airport_t` table available in the Postgresql and the `flights_t` available in the Object Store through Hive Metastore, we can finally use Trino's query federation capabilities to join the two tables using a `SELECT ... FROM ... LEFT JOIN` statement: 

```sql
SELECT ao.name, ao.municipality, ad.name, ad.municipality, f.*
FROM minio.flight_db.flights_t  AS f
LEFT JOIN postgresql.flight_data.pg_airport_t AS ao
ON (f.origin = ao.iata_code)
LEFT JOIN postgresql.flight_data.pg_airport_t AS ad
ON (f.destination = ad.iata_code);
```


Trino supports many other data sources in addition to Hive and PostgreSQL (RDBMS). 

Find [here the actual list of connectors](https://trino.io/docs/current/connector.html) Trino provides to connect to the various data sources.

