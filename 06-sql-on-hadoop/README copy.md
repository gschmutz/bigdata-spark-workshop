# Working with Object Storage

## Using Apache Spark to access Object Storage

In order to work with object storage, we have to add some additional libraries to Spark. On the command line we would use the `--jars` parameter to list the dependencies

```
pyspark --jars "../bin/hadoop-aws-2.8.2.jar,../bin/httpclient-4.5.3.jar,../bin/aws-java-sdk-core-1.11.524.jar,../bin/aws-java-sdk-kms-1.11.524.jar,../bin/aws-java-sdk-1.11.524.jar,../bin/aws-java-sdk-s3-1.11.524.jar,../bin/joda-time-2.9.9.jar"
```

But here we will demonstrate it using Apache Zeppelin. In a browser window navigate to <http://analyticsplatform:38081> and open the **Spark Interpreter**. We have seen how to do that in the [Spark Workshop](../05-spark/README.md).

We again have to add the `commons-lang3` library for the same reason as in the Spark workshop.
 
 * `org.apache.commons:commons-lang3:3.5` 

But now let's also add the following 7 additional dependencies

 * `org.apache.httpcomponents:httpclient:4.5.8`
 * `com.amazonaws:aws-java-sdk-core:1.11.524`
 * `com.amazonaws:aws-java-sdk-kms:1.11.524`
 * `com.amazonaws:aws-java-sdk:1.11.524`
 * `com.amazonaws:aws-java-sdk-s3:1.11.524`
 * `joda-time:joda-time:2.9.9`
 * `org.apache.hadoop:hadoop-aws:3.1.1`	

Your screen should look like the one below. 

![Alt Image Text](./images/zeppelin-add-s3-dep.png "Zeppelin Interpreter")

When finished click **Save**. 

Now create a new notebook using the **spark** interpreter as the default and in the first cell, let's try to create a DataFrame with the CSV file as the source:

```
%pyspark
geoDf = spark.read.csv("s3a://truck-bucket/raw/geolocation.csv")
```

We can see that we just have to replace the URI and use `s3a` prefix instead of `hdfs` to switch from HDFS to using Object Storage.  

Let's see if the Data Frame holds the correct data

```
%pyspark
geoDf.show()
```

Now let's also read the result data into different data frames. 

Let's start with the JSON format

```
%pyspark
truckMileageJson = spark.read.json("s3a://truck-bucket/result/json/truck_mileage.json")
truckMileageJson.show()
```

followed by the Parquet format


```
%pyspark
truckMileageParquet = spark.read.parquet("s3a://truck-bucket/result/parquet/truck_mileage.parquet")
truckMileageParquet.show()
```

and last but not least with the ORC format (this currently does not work!)

```
%pyspark
truckMileageOrc = spark.read.orc("s3a://truck-bucket/result/orc/truck_mileage.orc")
truckMileageOrc.show()
```

## Using Presto to access Object Storage

[Presto](https://prestosql.io/) is a distributed SQL query engine designed to query large data sets distributed over one or more heterogeneous data sources. Presto can natively query data in Hadoop, S3, Cassandra, MySQL, and many others, without the need for complex and error-prone processes for copying the data to a proprietary storage system. You can access data from multiple systems within a single query. For example, join historic log data stored in S3 with real-time customer data stored in MySQL. This is called **query federation**.

Make sure that the `presto` service is started as part of the analyticsplatform environment. The following definition has to be in the `docker-compose.yml` file. 

```
  presto:
    hostname: presto
    image: 'starburstdata/presto:302-e.7'
    container_name: presto
    ports:
      - '8089:8080'
    volumes: 
      - './conf/minio.properties:/usr/lib/presto/etc/catalog/minio.properties'
      - './conf/postgresql.properties:/usr/lib/presto/etc/catalog/minio.properties'
    restart: always
```

Create `minio.properties` file in the folder `conf` and add the following property definition: 

```
connector.name=hive-hadoop2
hive.metastore.uri=thrift://hive-metastore:9083
hive.s3.path-style-access=true
hive.s3.endpoint=http://minio:9000
hive.s3.aws-access-key=V42FCGRVMK24JJ8DHUYG
hive.s3.aws-secret-key=bKhWxVF3kQoLY9kFmt91l+tDrEoZjqnWXzY9Eza
hive.non-managed-table-writes-enabled=true
hive.s3.ssl.enabled=false
```

The docker image we use for the Presto container is from [Starbrust Data](https://www.starburstdata.com/), the company offering an Enterprise version of Presto. 

#### Create Table in Hive Metastore

In order to access data in HDFS or S3 using Presto, we have to create a table in the Hive metastore. Note that the location 's3a://truck-bucket/result/parquet' points to the data we have uploaded before.

Connect to hive CLI

```
docker exec -ti hive-server hive
```

and on the command prompt, execute the following `CREATE TABLE` statement.

```
CREATE EXTERNAL TABLE truck_mileage 
(truckid string, driverId string, rdate string, miles integer, gas integer, mpg double) 
STORED AS parquet 
LOCATION 's3a://truck-bucket/result/parquet/'; 
```

You can already test the mapping inside Hive:

```
SELECT *
FROM truck_mileage;
```

#### Query Hive Table from Presto

Next let's query the data from Presto. Connect to the Presto CLI using

```
docker exec -it presto presto-cli
```

Now on the Presto command prompt, switch to the right database. 

```
use minio.default;
```

Let's see that there is one table available:

```
show tables;
```

We can see the `truck_mileage` table we created in the Hive Metastore before

```
presto:default> show tables;
     Table
---------------
 truck_mileage
(1 row)
```

We can use the `DESCRIBE` command to see the structure of the table:

```
DESCRIBE minio.default.truck_mileage;
```

and you should get the following result

```
presto> DESCRIBE minio.default.truck_mileage;
  Column  |  Type   | Extra | Comment
----------+---------+-------+---------
 truckid  | varchar |       |
 driverid | varchar |       |
 rdate    | varchar |       |
 miles    | integer |       |
 gas      | integer |       |
 mpg      | double  |       |
```

We can query the table from the current database

```
SELECT * FROM truck_mileage;
```

We can execute the same query, but now with a fully qualified table, including the database:

```
SELECT * 
FROM minio.default.truck_mileage;
```

Presto also provides the [Presto UI](http://analyticsplatform:8089) for monitoring the queries executed on the presto server. 

## Using Presto to access a Relational Database

Make sure that the `postgresql` service is configured in the `docker-compose.yml`. 

```
  postgresql:
    image: postgres:10
    container_name: postgresql
    hostname: postgresql
    volumes: 
      - ./sql/create-driver.sql:/docker-entrypoint-initdb.d/create-driver.sql
    environment:
      POSTGRES_DB: truckdb
      POSTGRES_PASSWORD: truck
      POSTGRES_USER: truck
    restart: always
```

Also create a folder `sql` if not existing and create a script `create-driver.sql` with the following content:

```
CREATE SCHEMA truck;

CREATE TABLE truck.driver (id integer, id_str varchar(10), first_name varchar(100), last_name varchar(100), email varchar(50), gender varchar(10));
ALTER TABLE truck.driver ADD CONSTRAINT pk_driver PRIMARY KEY (id);

insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (1, 'A1', 'Cloe', 'Atcherley', 'catcherley0@youku.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (2, 'A2', 'Dorita', 'Duggan', 'dduggan1@thetimes.co.uk', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (3, 'A3', 'Antonietta', 'Rozsa', 'arozsa2@bluehost.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (4, 'A4', 'Anabel', 'MacCallion', 'amaccallion3@spiegel.de', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (5, 'A5', 'Shel', 'Mahody', 'smahody4@netscape.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (6, 'A6', 'Reinhold', 'McGuff', 'rmcguff5@ted.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (7, 'A7', 'Alphard', 'Woolcocks', 'awoolcocks6@angelfire.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (8, 'A8', 'Falkner', 'Gubbin', 'fgubbin7@epa.gov', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (9, 'A9', 'Nert', 'Hovell', 'nhovell8@ucla.edu', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (10, 'A10', 'Othella', 'Reuble', 'oreuble9@europa.eu', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (11, 'A11', 'Vivian', 'Geeves', 'vgeevesa@unblog.fr', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (12, 'A12', 'Rupert', 'Maher', 'rmaherb@geocities.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (13, 'A13', 'Farley', 'Hastwell', 'fhastwellc@opensource.org', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (14, 'A14', 'Grantham', 'Jervis', 'gjervisd@mayoclinic.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (15, 'A15', 'Dina', 'Spence', 'dspencee@google.de', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (16, 'A16', 'Frances', 'Gladding', 'fgladdingf@discuz.net', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (17, 'A17', 'Chilton', 'Kembley', 'ckembleyg@oaic.gov.au', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (18, 'A18', 'Dorian', 'Roggieri', 'droggierih@icq.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (19, 'A19', 'Tedra', 'Tregaskis', 'ttregaskisi@bizjournals.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (20, 'A20', 'Ada', 'Seabert', 'aseabertj@patch.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (21, 'A21', 'Maggi', 'Gilham', 'mgilhamk@amazon.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (22, 'A22', 'Deeanne', 'Deverale', 'ddeveralel@networkadvertising.org', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (23, 'A23', 'Mina', 'Hornbuckle', 'mhornbucklem@whitehouse.gov', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (24, 'A24', 'Sigismund', 'Milbourne', 'smilbournen@naver.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (25, 'A25', 'Rayner', 'Pimer', 'rpimero@harvard.edu', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (26, 'A26', 'Lockwood', 'Halwood', 'lhalwoodp@geocities.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (27, 'A27', 'Brigham', 'De Mars', 'bdemarsq@icq.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (28, 'A28', 'Rina', 'Lunbech', 'rlunbechr@buzzfeed.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (29, 'A29', 'Saunder', 'Togwell', 'stogwells@java.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (30, 'A30', 'De witt', 'Mansuer', 'dmansuert@nps.gov', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (31, 'A31', 'Giana', 'Barnhill', 'gbarnhillu@infoseek.co.jp', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (32, 'A32', 'Godwin', 'Strickland', 'gstricklandv@symantec.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (33, 'A33', 'Henka', 'Volkers', 'hvolkersw@cargocollective.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (34, 'A34', 'Helaina', 'Tice', 'hticex@bigcartel.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (35, 'A35', 'Des', 'Haithwaite', 'dhaithwaitey@bravesites.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (36, 'A36', 'Windham', 'Chown', 'wchownz@yelp.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (37, 'A37', 'Christophe', 'Pollington', 'cpollington10@instagram.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (38, 'A38', 'Korey', 'Weinmann', 'kweinmann11@google.nl', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (39, 'A39', 'Whitney', 'Frisch', 'wfrisch12@t.co', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (40, 'A40', 'Antonella', 'Jacob', 'ajacob13@histats.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (41, 'A41', 'Sloane', 'Maddin', 'smaddin14@admin.ch', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (42, 'A42', 'Hill', 'Braddon', 'hbraddon15@wikimedia.org', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (43, 'A43', 'Trev', 'Longbone', 'tlongbone16@stumbleupon.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (44, 'A44', 'Manny', 'Fintoph', 'mfintoph17@blog.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (45, 'A45', 'Fonsie', 'Crannage', 'fcrannage18@imageshack.us', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (46, 'A46', 'Zachary', 'Yeoman', 'zyeoman19@mashable.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (47, 'A47', 'Nan', 'Arthars', 'narthars1a@biglobe.ne.jp', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (48, 'A48', 'Alphard', 'Ickovits', 'aickovits1b@soup.io', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (49, 'A49', 'Casar', 'Djorvic', 'cdjorvic1c@uol.com.br', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (50, 'A50', 'Edouard', 'Lunney', 'elunney1d@irs.gov', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (51, 'A51', 'Edgardo', 'Olivie', 'eolivie1e@globo.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (52, 'A52', 'Ted', 'Barde', 'tbarde1f@ocn.ne.jp', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (53, 'A53', 'Ximenez', 'Denford', 'xdenford1g@google.com.br', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (54, 'A54', 'Junette', 'Sorbey', 'jsorbey1h@sakura.ne.jp', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (55, 'A55', 'Gabey', 'Biever', 'gbiever1i@vk.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (56, 'A56', 'Tait', 'Paule', 'tpaule1j@addthis.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (57, 'A57', 'Andrea', 'Aglione', 'aaglione1k@sohu.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (58, 'A58', 'Vivian', 'Crumbleholme', 'vcrumbleholme1l@aboutads.info', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (59, 'A59', 'Johnna', 'Marvelley', 'jmarvelley1m@ocn.ne.jp', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (60, 'A60', 'Bevvy', 'Rablen', 'brablen1n@xing.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (61, 'A61', 'Sioux', 'Pursey', 'spursey1o@wix.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (62, 'A62', 'Natty', 'Tacey', 'ntacey1p@wikispaces.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (63, 'A63', 'Vivyanne', 'Setchfield', 'vsetchfield1q@xinhuanet.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (64, 'A64', 'Whitby', 'Dudley', 'wdudley1r@nifty.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (65, 'A65', 'Otto', 'Redgate', 'oredgate1s@surveymonkey.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (66, 'A66', 'Killian', 'Alessandrelli', 'kalessandrelli1t@purevolume.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (67, 'A67', 'Mischa', 'de Clercq', 'mdeclercq1u@sourceforge.net', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (68, 'A68', 'Justis', 'Coverdill', 'jcoverdill1v@eepurl.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (69, 'A69', 'Gusty', 'Ruddock', 'gruddock1w@cam.ac.uk', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (70, 'A70', 'Kyrstin', 'Muzzollo', 'kmuzzollo1x@nymag.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (71, 'A71', 'Hazlett', 'Poynzer', 'hpoynzer1y@fda.gov', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (72, 'A72', 'Davina', 'McCrie', 'dmccrie1z@spiegel.de', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (73, 'A73', 'Anita', 'Dureden', 'adureden20@sfgate.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (74, 'A74', 'Fred', 'Bim', 'fbim21@freewebs.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (75, 'A75', 'Jessey', 'Gibling', 'jgibling22@ustream.tv', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (76, 'A76', 'Westley', 'Demaid', 'wdemaid23@mail.ru', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (77, 'A77', 'Alexi', 'Burle', 'aburle24@dell.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (78, 'A78', 'Dierdre', 'Challin', 'dchallin25@delicious.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (79, 'A79', 'Sheeree', 'Georgeon', 'sgeorgeon26@slate.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (80, 'A80', 'Roselia', 'Goodge', 'rgoodge27@mediafire.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (81, 'A81', 'Maury', 'Keefe', 'mkeefe28@google.es', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (82, 'A82', 'Fowler', 'Cambling', 'fcambling29@amazon.de', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (83, 'A83', 'August', 'Danilyak', 'adanilyak2a@com.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (84, 'A84', 'Titus', 'Eckery', 'teckery2b@gravatar.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (85, 'A85', 'Lowell', 'Wenzel', 'lwenzel2c@cnet.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (86, 'A86', 'Georgianne', 'Sparshatt', 'gsparshatt2d@tripod.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (87, 'A87', 'Dolley', 'Caville', 'dcaville2e@earthlink.net', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (88, 'A88', 'Lyndell', 'Haggart', 'lhaggart2f@slate.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (89, 'A89', 'Beaufort', 'Haddon', 'bhaddon2g@last.fm', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (90, 'A90', 'Royall', 'Schade', 'rschade2h@go.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (91, 'A91', 'Vivia', 'Seward', 'vseward2i@simplemachines.org', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (92, 'A92', 'Jo', 'Heard', 'jheard2j@patch.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (93, 'A93', 'Rhea', 'Mitchenson', 'rmitchenson2k@oracle.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (94, 'A94', 'Pearle', 'Hargrave', 'phargrave2l@patch.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (95, 'A95', 'Lynn', 'Breitling', 'lbreitling2m@sina.com.cn', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (96, 'A96', 'Otho', 'Muglestone', 'omuglestone2n@globo.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (97, 'A97', 'Giacinta', 'Leyre', 'gleyre2o@moonfruit.com', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (98, 'A98', 'Maren', 'Bakes', 'mbakes2p@i2i.jp', 'Female');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (99, 'A99', 'Devland', 'Grand', 'dgrand2q@wikispaces.com', 'Male');
insert into truck.driver (id, id_str, first_name, last_name, email, gender) values (100, 'A100', 'Norton', 'Geach', 'ngeach2r@admin.ch', 'Male');
```

This script first creates a `schema` and then adds the table `driver` with information of our truck drivers. 

Now let's query this table using presto. Connect to the `presto-cli`

```
docker exec -ti presto presto-cli
```

Show all the schemas available in the database

```
SHOW SCHEMAS FROM postgresql;
```

We can see the `truck` schemas created above

```
presto> SHOW SCHEMAS FROM postgresql;
       Schema       
--------------------
 information_schema 
 pg_catalog         
 public             
 truck              
(4 rows)
```

Let's see the tables in this schema

```
SHOW TABLES FROM postgresql.truck;
```

we can see our `driver` table

```
presto> SHOW TABLES FROM postgresql.truck;
 Table  
--------
 driver 
(1 row)
```

We can use `DESCRIBE` again to get the structure of the table.

```
DESCRIBE postgresql.truck.driver;
```

```
presto> DESCRIBE postgresql.truck.driver;
   Column   |     Type     | Extra | Comment 
------------+--------------+-------+---------
 id         | integer      |       |         
 id_str     | varchar(10)  |       |         
 first_name | varchar(100) |       |         
 last_name  | varchar(100) |       |         
 email      | varchar(50)  |       |         
 gender     | varchar(10)  |       |         
(6 rows)

```

Last but not least let's see the data in Presto. 

```
SELECT * 
FROM postgresql.truck.driver;
```

## Query Federation using Presto

With the `driver` table available in the Postgresql and the `truck_mileage` available in the Object Store through Hive, we can use Presto's query federation capabilities to join the two tables using a `SELECT ... FROM ... LEFT JOIN` statement: 

```
SELECT d.id, d.id_str, d.first_name, d.last_name, tm.truckid, tm.miles, tm.gas 
FROM minio.default.truck_mileage AS tm
LEFT JOIN postgresql.truck.driver AS d
ON (tm.driverid = d.id_str)
WHERE rdate = 'jun13'; 
```
