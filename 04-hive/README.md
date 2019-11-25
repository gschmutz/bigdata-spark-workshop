# Data Manipulation with Hive

## Introduction
In this workshop we will work with [Apache Hive](https://hive.apache.org/) to analyse data through SQL.

Hive is an SQL like query language that enables analysts familiar with SQL to run queries on large volumes of data. Hive has three main functions: data summarisation, query and analysis. Hive provides tools that enable easy data extraction, transformation and loading (ETL).

We assume that the **Analytics platform** described [here](../01-environment) is running and accessible. 

##	 Accessing Hive

The Apache Hive ™ data warehouse software facilitates reading, writing, and managing large datasets residing in distributed storage using SQL. Structure can be projected onto data already in storage. A command line tool and JDBC driver are provided to connect users to Hive.

There are various ways for accessing Hive. In this workshop we will use the following

 * **Hive CLI** - accessing Hive from the command line
 * **Hue** - a browser based GUI for working with a Hadoop cluster

There would also be the option to use **HiveServer2** and use Hive from any tool supporting ODBC or JDBC. But this is not covered in this workshop.

### Using the Hive CLI
The [Hadoop CLI](https://cwiki.apache.org/confluence/display/Hive/LanguageManual+Cli) allows us to work with Hadoop and HDFS through the command line. 
We can use it to create tables, load data into a table and query from tables.

In our environment, the Hadoop command is accessible inside the `hive-server` container. To connect to the Hive over the Hive CLI use the `hive` command. To get the help page run

```
docker exec -ti hive-server hive -h
```

and you should get the help page in return

```
$ docker exec -ti hive-server hive -h
SLF4J: Class path contains multiple SLF4J bindings.
SLF4J: Found binding in [jar:file:/opt/hive/lib/log4j-slf4j-impl-2.6.2.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: Found binding in [jar:file:/opt/hadoop-2.7.4/share/hadoop/common/lib/slf4j-log4j12-1.7.10.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: See http://www.slf4j.org/codes.html#multiple_bindings for an explanation.
SLF4J: Actual binding is of type [org.apache.logging.slf4j.Log4jLoggerFactory]
Unrecognized option: -h
usage: hive
 -d,--define <key=value>          Variable substitution to apply to Hive
                                  commands. e.g. -d A=B or --define A=B
    --database <databasename>     Specify the database to use
 -e <quoted-query-string>         SQL from command line
 -f <filename>                    SQL from files
 -H,--help                        Print help information
    --hiveconf <property=value>   Use value for given property
    --hivevar <key=value>         Variable substitution to apply to Hive
                                  commands. e.g. --hivevar A=B
 -i <filename>                    Initialization SQL file
 -S,--silent                      Silent mode in interactive shell
 -v,--verbose                     Verbose mode (echo executed SQL to the
                                  console)
```

To connect to Hive, just use the command without the `-h` option

```
docker exec -ti hive-server hive
```

Now on the command prompt `hive>` you can enter the hive commands. Let's list the available databases.

```
hive> show databases;
OK
default
Time taken: 0.94 seconds, Fetched: 2 row(s)
hive> 
```

### Using Hue

[Hue](http://gethue.com/) is a web-based interactive query editor in the Hadoop stack that lets you visualise and share data.

In a browser window, navigate to <http://analyticsplatform:28888> and sign in with user `hue` and password `hue`. You should be forwarded to the **Hue** homepage. 

If asked for the tour through Hue, either follow it, or just close the window. You should end up on the Hue homepage.

![Alt Image Text](./images/hue-homepage.png "Hue Home Page")

To access the Hive Query, navigate to the menu by clicking on the "database" icon in the top left corner. On the left you should see a menu showing Hive and the available databases, wich currently is just the default database.

![Alt Image Text](./images/hue-hive-databases.png "Hive Databases")

If you click on the **Query** drop-down, the Query Editor will be shown in the detail section. 

![Alt Image Text](./images/hue-hive-query-editor.png "Hive Query Editor")

Enter the commands into the query window and execute it either using the **>** icon to the left or hitting **CTRL + ENTER** on the keyboard. You can also use the `show databases` command to display the Hive databases here.

![Alt Image Text](./images/hue-hive-query-editor-show-db.png "Hive Query Editor")

## Working with Hive

Apache Hive presents a relational view of data in HDFS and ensures that users need not worry about where or in what format their data is stored. Hive can display data from RCFile format, text files, ORC, JSON, parquet, sequence files and many of other formats in a tabular view. 

Through the use of SQL you can view your data as a table and create queries like you would in an RDBMS.

First let's upload the data needed for this workshop, using the techniques we have learned in the [HDFS Workshop](../02-hdfs/README.md).

### Upload Raw Data

In this workshop we are working with truck data. The files are also available in the `data-transfer` folder of the Analytics Platform: [/01-environment/docker/data-transfer/flightdata](../01-environment/docker/data-transfer/truckdata).

In HDFS under the folder `/user/hue` create a new folder `truckdata` and upload the two files into that folder. 

Here are the commands to perform when using the **Hadoop Filesystem Command** on the commmand line

```
docker exec -ti namenode hadoop fs -mkdir -p /user/hue/truckdata/

docker exec -ti namenode hadoop fs -copyFromLocal /data-transfer/truckdata/geolocation.csv /user/hue/truckdata/
docker exec -ti namenode hadoop fs -copyFromLocal /data-transfer/truckdata/trucks.csv /user/hue/truckdata/

docker exec -ti namenode hadoop fs -ls /user/hue/truckdata/
```

Now with the raw data in HDFS, let's create some tables and load them. 

### Create a Database for the Truck Data

First let's create a Hive database for holding the tables.

You can either use the `CREATE DATABASE` statement in **Hive CLI** or **Hue**

```
CREATE DATABASE truckdb;
```

Or in Hue there is also a graphical way using the **+** sign next to the Databases list on the left side.

![Alt Image Text](./images/hue-create-database.png "Hue Create Database")

To see the databases in place, execute the following command in either **Hive CLI** or **Hue** 

```
SHOW databases;
```

In **Hue** you can also click on the refresh icon, next to the **Databases**.

![Alt Image Text](./images/hue-refresh-db.png "Refresh DBs")

### Create Hive Staging Tables

Now that you are familiar with the Hive User View, let’s create the initial staging tables for the geolocation and trucks data. In this section we will learn how to create four Hive tables: `geolocation_stage`, `trucking_stage`, `geolocation`, `trucking`.

First we are going to create the two tables to stage the data in their original CSV text format and then we will create two more tables where we will optimise the storage with ORC. 

Here is a visual representation of the Data Flow:

![Alt Image Text](./images/use-case-diagram.png "Use Case Diagram")

The following statements can either be executed using the Hive CLI or the **Hue Query Editor**. Screenshots of how to use it via **Hue** will be shown together with the description of the various tasks. 

Make sure that you switch to the `trucksdb` database created above, before you perform the next steps. You can either to it in **Hive CLI** using

```
use truckdb;
```

or in **Hue** using the Drop-Down on the top of the Query Editor

![Alt Image Text](./images/hue-switch-database.png "Use Case Diagram")

	
#### Create Table GEOLOCATION_STAGE for staging initial load

To create the table named `geolocation_stage` execute the following `CREATE TABLE` statement

```
CREATE TABLE geolocation_stage (truckid string, driverid string, event string, latitude DOUBLE, longitude DOUBLE, city string, state string, velocity BIGINT, event_ind BIGINT, idling_ind BIGINT)
	ROW FORMAT DELIMITED
	FIELDS TERMINATED BY ','
	STORED AS TEXTFILE
	TBLPROPERTIES ("skip.header.line.count"="1");
```

It reflects the format of the CSV file `geolocation.csv`. 

![Alt Image Text](./images/hue-create-geolocation-stage.png "Use Case Diagram")

Click the green **Execute** button to run the command. 

Let’s review some aspects of the **CREATE TABLE** statements issued above. If you have an SQL background this statement should seem very familiar except for the last 3 lines after the columns definition:

* The **ROW FORMAT** clause specifies each row is terminated by the new line character.
* The **FIELDS TERMINATED BY** clause specifies that the fields associated with the
table (in our case, the two CSV files) are to be delimited by a comma.
* The **STORED AS** clause specifies that the table will be stored in the TEXTFILE
format.

For details on these clauses consult the [Apache Hive Language Manual](https://cwiki.apache.org/confluence/display/Hive/LanguageManual+DDL).

#### Create Table `trucks_stage` for Staging Initial Load

Now create the `trucks_stage` table in the same way as the `geolocation_stage`. 

```
CREATE TABLE trucks_stage(driverid string, truckid string, model string, 
          jun13_miles bigint, jun13_gas bigint, 
          may13_miles bigint, may13_gas bigint, 
          apr13_miles bigint, apr13_gas bigint, 
          mar13_miles bigint, mar13_gas bigint, 
          feb13_miles bigint, feb13_gas bigint, 
          jan13_miles bigint, jan13_gas bigint, 
          dec12_miles bigint, dec12_gas bigint, 
          nov12_miles bigint, nov12_gas bigint, 
          oct12_miles bigint, oct12_gas bigint, 
          sep12_miles bigint, sep12_gas bigint, 
          aug12_miles bigint, aug12_gas bigint, 
          jul12_miles bigint, jul12_gas bigint, 
          jun12_miles bigint, jun12_gas bigint,
          may12_miles bigint, may12_gas bigint, 
          apr12_miles bigint, apr12_gas bigint, 
          mar12_miles bigint, mar12_gas bigint, 
          feb12_miles bigint, feb12_gas bigint, 
          jan12_miles bigint, jan12_gas bigint, 
          dec11_miles bigint, dec11_gas bigint, 
          nov11_miles bigint, nov11_gas bigint, 
          oct11_miles bigint, oct11_gas bigint, 
          sep11_miles bigint, sep11_gas bigint, 
          aug11_miles bigint, aug11_gas bigint, 
          jul11_miles bigint, jul11_gas bigint, 
          jun11_miles bigint, jun11_gas bigint, 
          may11_miles bigint, may11_gas bigint, 
          apr11_miles bigint, apr11_gas bigint, 
          mar11_miles bigint, mar11_gas bigint, 
          feb11_miles bigint, feb11_gas bigint, 
          jan11_miles bigint, jan11_gas bigint, 
          dec10_miles bigint, dec10_gas bigint, 
          nov10_miles bigint, nov10_gas bigint, 
          oct10_miles bigint, oct10_gas bigint, 
          sep10_miles bigint, sep10_gas bigint, 
          aug10_miles bigint, aug10_gas bigint, 
          jul10_miles bigint, jul10_gas bigint, 
          jun10_miles bigint, jun10_gas bigint, 
          may10_miles bigint, may10_gas bigint, 
          apr10_miles bigint, apr10_gas bigint, 
          mar10_miles bigint, mar10_gas bigint, 
          feb10_miles bigint, feb10_gas bigint, 
          jan10_miles bigint, jan10_gas bigint, 
          dec09_miles bigint, dec09_gas bigint, 
          nov09_miles bigint, nov09_gas bigint, 
          oct09_miles bigint, oct09_gas bigint, 
          sep09_miles bigint, sep09_gas bigint, 
          aug09_miles bigint, aug09_gas bigint, 
          jul09_miles bigint, jul09_gas bigint, 
          jun09_miles bigint, jun09_gas bigint, 
          may09_miles bigint, may09_gas bigint, 
          apr09_miles bigint, apr09_gas bigint, 
          mar09_miles bigint, mar09_gas bigint, 
          feb09_miles bigint, feb09_gas bigint, 
          jan09_miles bigint, jan09_gas bigint)
	ROW FORMAT DELIMITED
	FIELDS TERMINATED BY ','
	STORED AS TEXTFILE
	TBLPROPERTIES ("skip.header.line.count"="1");
```

The structure and properties again reflects the format of the CSV file `trucks.csv`. It is a very wide table, representing the many columns of the CSV file. 

### Verify that the 2 new tables exist

To verify the tables were defined successfully, in **Hue** or **Hive CLI** execute

```
show tables;
```

In **Hue** you navigate into the database on the left side and you should see the tables. If not you have to hit the refresh icon. 

![Alt Image Text](./images/hue-show-tables.png "Use Case Diagram")

So we have created two tables, but do they already contain the data? 

A simple query can answer that question

```
SELECT * FROM trucks_stage;
```
We can see that the `trucks_stage` table **does not yet hold any data**. This should be the same for the other table as well.

If you are using **Hue** to query the tables, then make sure that you select the right database in the drop-down on the top of the Query Browser.

![Alt Image Text](./images/hue-select-from-stage-table.png "Select Stage Table")


We have created the tables in the **Hive Datawarehouse**, but our files in HDFS are located somewhere else. By default, when you create a table in Hive, a directory with the same name gets created in the `/user/hive/warehouse` folder in HDFS. 

Using the **File Browser**, navigate to the `/user/hive/warehouse` folder and you should find a `truckdb.db` folder, which itself holds one folder for each table. 

![Alt Image Text](./images/hue-show-warehouse-folder.png "Select Stage Table")

Both the `geolocation_stage` and the `trucks_stage` are currently empty, although the table is fully functioning, which is the reason why the SELECT query before returned zero rows. 

We could have created the table as **EXTERNAL** and link it with the location of the file in the `CREATE TABLE` clause. 

In this workshop we will manually move the data from the HDFS folder to the right place.

### Load data into the Staging tables

The definition of a Hive table and it's associated metadata (i.e., the directory the data is stored in, the file format, what Hive properties are set, etc.) are stored in the Hive metastore, which in our environment is located in a PostgreSQL instance.

Let’s load the data into your two Hive tables. Populating a Hive table can be done in various ways. A simple way to populate a table is to put a file into the directory associated with the table. 

#### Move the file using HDFS commands

In the **File Browser** View, navigate to the file `/user/hue/truckdata/geolocation.csv` and select it. 

Now click on **Actions** | **Move** and select the `/user/hive/warehouse/truckdb.db/geolocation_stage` folder as the **Move to** target and click **Move**. 

The file has now been moved to the Hive warehouse. 

Another query on the table should now return the data:

```
SELECT * FROM geolocation_stage;
```

#### Use the `LOAD DATA INPATH` command

To load the trucks data we use another, more automatic approach through Hive. Execute the following SQL command

```
LOAD DATA INPATH '/user/hue/truckdata/trucks.csv' OVERWRITE INTO TABLE trucks_stage;
```

This also copies the data from the HDFS folder to the folder of the `trucks_stage` table. 

A quick check with a SELECT reveals that it has worked

```
SELECT COUNT(*) FROM trucks_stage;
```

**Note**: using this approach, we don't have to know exactly where the data in the warehouse is located, Hive is doing that work for us. 

If we now navigate back to the `/user/hue/truckdata`  folder, we can see that it is empty! We have successfully moved the data into the Hive warehouse. 

The next step will be to provide that data to potential consumers in a more efficient manner by usiing an columnar format instead of a text format. 

### Define an ORC Table in Hive

The **Optimized Row Columnar**  file format ([Apache ORC](https://orc.apache.org/) project) provides a highly efficient way to store Hive data. It was designed to overcome limitations of the other Hive file formats. Using ORC files improves performance when Hive is reading, writing, and processing data.

To use the ORC format, specify ORC as the file format when creating the table `CREATE TABLE ... STORED AS ORC`

We will create two ORC tables, one for geolocation and one for trucks, which will be created from the data in the **geolocation_stage** and **trucks_stage** tables (which are based on the less optimal text format).

```
CREATE TABLE geolocation 
STORED AS ORC AS 
SELECT * 
FROM geolocation_stage;
```

We have successfully moved our raw data from the stating zone into the refined zone. 
In real life we might also perform some cleansing and processing in that step.

To see that the new table holds the data, just perform a simple SELECT query

```
SELECT * 
FROM geolocation
LIMIT 10;
```

To verify that the `geolocation` table is using the ORC format, execute the following query

```
DESCRIBE formatted geolocation;
```

The result should be similar to the one shown below
	
```
hive> DESCRIBE formatted geolocation;
OK
# col_name            	data_type           	comment

truckid             	string
driverid            	string
event               	string
latitude            	double
longitude           	double
city                	string
state               	string
velocity            	bigint
event_ind           	bigint
idling_ind          	bigint

# Detailed Table Information
Database:           	truckdb
Owner:              	root
CreateTime:         	Wed May 15 06:07:30 UTC 2019
LastAccessTime:     	UNKNOWN
Retention:          	0
Location:           	hdfs://namenode:8020/user/hive/warehouse/truckdb.db/geolocation
Table Type:         	MANAGED_TABLE
Table Parameters:
	COLUMN_STATS_ACCURATE	{\"BASIC_STATS\":\"true\"}
	numFiles            	1
	numRows             	8000
	rawDataSize         	3904000
	totalSize           	52817
	transient_lastDdlTime	1557900450

# Storage Information
SerDe Library:      	org.apache.hadoop.hive.ql.io.orc.OrcSerde
InputFormat:        	org.apache.hadoop.hive.ql.io.orc.OrcInputFormat
OutputFormat:       	org.apache.hadoop.hive.ql.io.orc.OrcOutputFormat
Compressed:         	No
Num Buckets:        	-1
Bucket Columns:     	[]
Sort Columns:       	[]
Storage Desc Params:
	serialization.format	1
Time taken: 0.124 seconds, Fetched: 39 row(s)
```	
	
We can see that for the SerDe infact the OrcSerde is used. Compare that with the `geolocation_stage` table. 

```
DESCRIBE formatted geolocation_stage;
```

Now let's perform the same operation also for the `trucks_stage` table. 

```
CREATE TABLE trucks 
STORED AS ORC TBLPROPERTIES ("orc.compress.size"="1024") AS 
SELECT * 
FROM trucks_stage;
```

With the two tables in place in a query-optimal form, let's perform some analytics on it. 

## Analyse the Truck Data

Next we will be using Hive to analyse derived data from the `geolocation` and `trucks` tables. 

Let’s get started with the first transformation.  We want to calculate the miles per gallon for each truck. 

We will start with the `trucks` table.  We need to sum up all the miles and gas columns on a per truck basis. Hive has a series of functions that can be used to reformat a table. The keyword `LATERAL VIEW` is how we invoke things. [Lateral View](https://cwiki.apache.org/confluence/display/Hive/LanguageManual+LateralView) is used in conjunction with [user-defined table generating functions (UDTF)](https://cwiki.apache.org/confluence/display/Hive/LanguageManual+UDF#LanguageManualUDF-Built-inTable-GeneratingFunctions(UDTF)). A UDTF generates zero or more output rows for each input row. A lateral view first applies the UDTF to each row of base table and then joins resulting output rows to the input rows to form a virtual table having the supplied table alias.

The `stack` UDTF allows us to restructure the data (jun13 to jan09) into 3 columns labeled `rdate`, `mile` and `gas` (ex: `"june13"`, `june13_miles`, `june13_gas`) that make up a maximum of 54 rows. 

We pick `truckid`, `driverid`, `rdate`, `miles` and `gas` from our original table and add a calculated column `mpg` (miles/gas).

Let’s create the table `truck_mileage` from existing trucking data.

```
CREATE TABLE truck_mileage 
AS SELECT truckid, driverid, rdate, miles, gas, miles / gas mpg 
FROM trucks 
LATERAL VIEW stack(54,
				'jun13',jun13_miles,jun13_gas,
				'may13',may13_miles,may13_gas,
				'apr13',apr13_miles,apr13_gas,
				'mar13',mar13_miles,mar13_gas,
				'feb13',feb13_miles,feb13_gas,
				'jan13',jan13_miles,jan13_gas,
				'dec12',dec12_miles,dec12_gas,
				'nov12',nov12_miles,nov12_gas,
				'oct12',oct12_miles,oct12_gas,
				'sep12',sep12_miles,sep12_gas,
				'aug12',aug12_miles,aug12_gas,
				'jul12',jul12_miles,jul12_gas,
				'jun12',jun12_miles,jun12_gas,
				'may12',may12_miles,may12_gas,
				'apr12',apr12_miles,apr12_gas,
				'mar12',mar12_miles,mar12_gas,
				'feb12',feb12_miles,feb12_gas,
				'jan12',jan12_miles,jan12_gas,
				'dec11',dec11_miles,dec11_gas,
				'nov11',nov11_miles,nov11_gas,
				'oct11',oct11_miles,oct11_gas,
				'sep11',sep11_miles,sep11_gas,
				'aug11',aug11_miles,aug11_gas,
				'jul11',jul11_miles,jul11_gas,
				'jun11',jun11_miles,jun11_gas,
				'may11',may11_miles,may11_gas,
				'apr11',apr11_miles,apr11_gas,
				'mar11',mar11_miles,mar11_gas,
				'feb11',feb11_miles,feb11_gas,
				'jan11',jan11_miles,jan11_gas,
				'dec10',dec10_miles,dec10_gas,
				'nov10',nov10_miles,nov10_gas,
				'oct10',oct10_miles,oct10_gas,
				'sep10',sep10_miles,sep10_gas,
				'aug10',aug10_miles,aug10_gas,
				'jul10',jul10_miles,jul10_gas,
				'jun10',jun10_miles,jun10_gas,
				'may10',may10_miles,may10_gas,
				'apr10',apr10_miles,apr10_gas,
				'mar10',mar10_miles,mar10_gas,
				'feb10',feb10_miles,feb10_gas,
				'jan10',jan10_miles,jan10_gas,
				'dec09',dec09_miles,dec09_gas,
				'nov09',nov09_miles,nov09_gas,
				'oct09',oct09_miles,oct09_gas,
				'sep09',sep09_miles,sep09_gas,
				'aug09',aug09_miles,aug09_gas,
				'jul09',jul09_miles,jul09_gas,
				'jun09',jun09_miles,jun09_gas,
				'may09',may09_miles,may09_gas,
				'apr09',apr09_miles,apr09_gas,
				'mar09',mar09_miles,mar09_gas,
				'feb09',feb09_miles,feb09_gas,
				'jan09',jan09_miles,jan09_gas ) dummyalias AS rdate, miles, gas;
```
	
From that table, let's calculate the average mileage. Let's first find the correct result using just a query statement

```
SELECT truckid, avg(mpg) avgmpg 
FROM truck_mileage 
GROUP BY truckid;
```

When we are happy with the result, we can embed the statement in a `CREATE TABLE ... AS ... ` 

```
CREATE TABLE avg_mileage
STORED AS ORC
AS
SELECT truckid, avg(mpg) avgmpg
FROM truck_mileage
GROUP BY truckid;
```

It’s a fairly common pattern in Hive to persist results into a table. It is called [Create Table as Select (CTAS)](https://cwiki.apache.org/confluence/display/Hive/LanguageManual+DDL#LanguageManualDDL-CreateTableAsSelect%28CTAS%29). 

## Hive Partitioned Table
Hive is a good tool for performing queries on large datasets, especially datasets that require full table scans. But quite often there are instances where users need to filter the data on specific column values. Generally, Hive users know about the domain of the data that they deal with. With this knowledge they can identify common columns that are frequently queried in order to identify columns with low cardinality which can be used to organize data using the partitioning feature of Hive. In non-partitioned tables, Hive would have to read all the files in a table’s data directory and subsequently apply filters on it. This is slow and expensive—especially in cases of large tables.

The concept of partitioning is not new for folks who are familiar with relational databases. Partitions are essentially horizontal slices of data which allow larger sets of data to be separated into more manageable chunks. In Hive, partitioning is supported for both managed and external tables.

We will create a `flight` table, which is partitioned by YEAR and MONTH and is holding flights for 2008.

Start Hive on the `hive-server` container

```
docker exec -ti hive-server hive
```

Now create a database and switch to that database;

```
CREATE DATABASE flightdata;
USE flightdata;
```

First let's create a partitioned table.

```
CREATE TABLE `flight` (
  `dayofmonth` bigint,
  `dayofweek` bigint,
  `deptime` bigint,
  `crsdeptime` bigint,
  `arrtime` bigint,
  `crsarrtime` bigint,
  `uniquecarrier` string,
  `flightnum` bigint,
  `tailnum` string,
  `actualelapsedtime` bigint,
  `crselapsedtime` bigint,
  `airtime` bigint,
  `arrdelay` bigint,
  `depdelay` bigint,
  `origin` string,
  `dest` string,
  `distance` bigint,
  `taxiin` bigint,
  `taxiout` bigint,
  `cancelled` boolean,
  `cancellationcode` string,
  `diverted` boolean,
  `carrierdelay` string,
  `weatherdelay` string,
  `nasdelay` string,
  `securitydelay` string,
  `lateaircraftdelay` string)
PARTITIONED BY (`year` bigint, `month` bigint)
ROW FORMAT SERDE
  'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES (
  'colelction.delim'='',
  'field.delim'=',',
  'mapkey.delim'='',
  'serialization.format'=',')
STORED AS INPUTFORMAT
  'org.apache.hadoop.mapred.TextInputFormat'
OUTPUTFORMAT
  'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
TBLPROPERTIES (
  'skip.header.line.count'='1',
  'transient_lastDdlTime'='1573991877');
```

Now let's load the data using the `LOAD DATA LOCAL` command, which allows us to load a local file (local to the `hive-server` container) into a Hive table. By using the partition clause, we can specify the partition it should be loaded into. Still in the hive shell perform:

```
LOAD DATA LOCAL INPATH '/data-transfer/flightdata/flights_2008_1.csv' 
OVERWRITE INTO TABLE flight PARTITION (year='2008',month=1);

LOAD DATA LOCAL INPATH '/data-transfer/flightdata/flights_2008_2.csv' 
OVERWRITE INTO TABLE flight PARTITION (year='2008',month=2);

LOAD DATA LOCAL INPATH '/data-transfer/flightdata/flights_2008_3.csv' 
OVERWRITE INTO TABLE flight PARTITION (year='2008',month=3);

LOAD DATA LOCAL INPATH '/data-transfer/flightdata/flights_2008_4.csv' 
OVERWRITE INTO TABLE flight PARTITION (year='2008',month=4);

LOAD DATA LOCAL INPATH '/data-transfer/flightdata/flights_2008_5.csv' 
OVERWRITE INTO TABLE flight PARTITION (year='2008',month=5);

LOAD DATA LOCAL INPATH '/data-transfer/flightdata/flights_2008_6.csv' 
OVERWRITE INTO TABLE flight PARTITION (year='2008',month=6 );

LOAD DATA LOCAL INPATH '/data-transfer/flightdata/flights_2008_7.csv' 
OVERWRITE INTO TABLE flight PARTITION (year='2008',month=7 );

LOAD DATA LOCAL INPATH '/data-transfer/flightdata/flights_2008_8.csv' 
OVERWRITE INTO TABLE flight PARTITION (year='2008',month=8 );

LOAD DATA LOCAL INPATH '/data-transfer/flightdata/flights_2008_9.csv' 
OVERWRITE INTO TABLE flight PARTITION (year='2008',month=9 );

LOAD DATA LOCAL INPATH '/data-transfer/flightdata/flights_2008_10-1.csv' 
OVERWRITE INTO TABLE flight PARTITION (year='2008',month=10 );

LOAD DATA LOCAL INPATH '/data-transfer/flightdata/flights_2008_10-2.csv' 
OVERWRITE INTO TABLE flight PARTITION (year='2008',month=10 );

LOAD DATA LOCAL INPATH '/data-transfer/flightdata/flights_2008_11.csv' 
OVERWRITE INTO TABLE flight PARTITION (year='2008',month=11 );

LOAD DATA LOCAL INPATH '/data-transfer/flightdata/flights_2008_12.csv' 
OVERWRITE INTO TABLE flight PARTITION (year='2008',month=12 );
```

Now let's see how the files have been loaded. We have created a managed table, so the table data is under `/user/hive/warehouse`. You can use the `dfs` command from the Hive shell to execute HDFS commands. 

A `dfs -ls -R` performs a folder listing recursively:

```
dfs -ls -R /user/hive/warehouse/flightdata.db;
```

you should see an output similar to the one shown below:

```
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=1
-rwxrwxr-x   3 root supergroup   60577093 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=1/flights_2008_1.csv
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=10
-rwxrwxr-x   3 root supergroup   47487359 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=10/flights_2008_10-2.csv
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=11
-rwxrwxr-x   3 root supergroup   53127605 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=11/flights_2008_11.csv
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=12
-rwxrwxr-x   3 root supergroup   54998023 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=12/flights_2008_12.csv
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=2
-rwxrwxr-x   3 root supergroup   56824186 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=2/flights_2008_2.csv
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=3
-rwxrwxr-x   3 root supergroup   61561755 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=3/flights_2008_3.csv
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=4
-rwxrwxr-x   3 root supergroup   59867299 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=4/flights_2008_4.csv
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=5
-rwxrwxr-x   3 root supergroup   25650829 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=5/flights_2008_5.csv
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=6
-rwxrwxr-x   3 root supergroup   60790288 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=6/flights_2008_6.csv
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=7
-rwxrwxr-x   3 root supergroup   62857510 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=7/flights_2008_7.csv
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=8
-rwxrwxr-x   3 root supergroup   61344436 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=8/flights_2008_8.csv
drwxrwxr-x   - root supergroup          0 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=9
-rwxrwxr-x   3 root supergroup   54305392 2019-11-17 23:13 /user/hive/warehouse/flightdata.db/flight/year=2008/month=9/flights_2008_9.csv
```

We can see that the partitioning is part of the folder naming: /user/hive/warehouse/flightdata.db/flight/**year=2008**/**month=9**/flights\_2008\_9.csv.

If you include both `year` and `month` in a query, then only the given partition is read by Hive. 

```
SELECT count(*) FROM flight WHERE year = 2008 and month = 2;
```

You can check that by using the `explain dependency` followed by the SELECT you would execute

```
explain dependency SELECT count(*) FROM flight WHERE year = 2008 and month = 2;
```

should return

```
OK
{"input_tables":[{"tablename":"default@flight","tabletype":"MANAGED_TABLE"}],"input_partitions":[{"partitionName":"default@flight@year=2008/month=2"}]}
```

whereas a select without where clause

```
explain dependency SELECT count(*) FROM flight;
```

as expected, has to read all the partitions

```
OK
{"input_tables":[{"tablename":"default@flight","tabletype":"MANAGED_TABLE"}],"input_partitions":[{"partitionName":"default@flight@year=2008/month=1"},{"partitionName":"default@flight@year=2008/month=2"},{"partitionName":"default@flight@year=2008/month=3"},{"partitionName":"default@flight@year=2008/month=4"},{"partitionName":"default@flight@year=2008/month=5"},{"partitionName":"default@flight@year=2008/month=6"},{"partitionName":"default@flight@year=2008/month=7"},{"partitionName":"default@flight@year=2008/month=8"},{"partitionName":"default@flight@year=2008/month=9"},{"partitionName":"default@flight@year=2008/month=10"},{"partitionName":"default@flight@year=2008/month=11"},{"partitionName":"default@flight@year=2008/month=12"}]}
```

You can force having to use a partition by setting the `hive.mapred.mode` to strict.

```
set hive.mapred.mode=strict;
```

Now a query without restricting on one of the partition keys will return with an error:

```
hive> select * from flight;
FAILED: SemanticException Queries against partitioned tables without a partition filter are disabled for safety reasons. If you know what you are doing, please sethive.strict.checks.large.query to false and that hive.mapred.mode is not set to 'strict' to proceed. Note that if you may get errors or incorrect results if you make a mistake while using some of the unsafe features. No partition predicate for Alias "flight" Table "flight"
```

## Summary

We have learnt that we can create Hive tables with **CREATE TABLE** and load data into them using the **LOAD DATA INPATH** command. Additionally, we have seen how to change the file format of the tables to ORC, so hive is more efficient at reading, writing and processing the underlying data. 

We have also learned how to grap column values from our existing table using **SELECT {column_name…} FROM {table_name}** to create a new table.
