# Data Reading and Writing using Spark RDD and DataFrames

## Introduction

In this workshop we will work with [Apache Spark](https://spark.apache.org/) and implement some basic operations using the Spark DataFrame API for Python. 

We assume that the **Analytics platform** described [here](../01-environment) is running and accessible. 

The same data as in the [Hive Workshop](../04-hive/README.md) will be used. 

##	 Accessing Spark

[Apache Spark](https://spark.apache.org/) is a fast, in-memory data processing engine with elegant and expressive development APIs in Scala, Java, and Python that allow data workers to efficiently execute machine learning algorithms that require fast iterative access to datasets. Spark on Apache Hadoop YARN enables deep integration with Hadoop and other YARN enabled workloads in the enterprise.

You can run batch application such as MapReduce types jobs or iterative algorithms that build upon each other. You can also run interactive queries and process streaming data with your application. Spark also provides a number of libraries which you can easily use to expand beyond the basic Spark capabilities such as Machine Learning algorithms, SQL, streaming, and graph processing. Spark runs on Hadoop clusters such as Hadoop YARN or Kubernetes, or even in a Standalone Mode with its own scheduler.

There are various ways for accessing Spark

 * **PySpark** - accessing Hive from the command line
 * **Apache Zeppelin** - a browser based GUI for working with various tools of the Big Data ecosystem
 * **Jupyter** - a browser based GUI for working with a Python and Spark

There is also the option to use **Thrift Server** to execute Spark SQL from any tool supporting SQL. But this is not covered in this workshop.

### Using the Python API through PySpark

The [PySpark API](https://spark.apache.org/docs/latest/api/python/index.html) allows us to work with Spark through the command line. 

In our environment, PySpark is accessible inside the `spark-master` container. To start PySpark use the `pyspark` command. 

```
docker exec -ti spark-master pyspark
```

and you should end up on the **pyspark** command prompt `>>>` as shown below

```
bigdata@bigdata:~$ docker exec -ti spark-master pyspark

Python 2.7.16 (default, Jan 14 2020, 07:22:06)
[GCC 8.3.0] on linux2
Type "help", "copyright", "credits" or "license" for more information.
Setting default log level to "WARN".
To adjust logging level use sc.setLogLevel(newLevel). For SparkR, use setLogLevel(newLevel).
Welcome to
      ____              __
     / __/__  ___ _____/ /__
    _\ \/ _ \/ _ `/ __/  '_/
   /__ / .__/\_,_/_/ /_/\_\   version 2.4.5
      /_/

Using Python version 2.7.16 (default, Jan 14 2020 07:22:06)
SparkSession available as 'spark'.
>>>
```

You have an active `SparkSession` available as the `spark` variable. Enter any valid command, just to test we can ask Spark for the version which is installed. 

```
>>> spark.version
u'2.4.5'
```

You can use `pyspark` for this workshop. But there are also two other, browser-based tools which are much more comfortable to use and which additionally allow to store the different steps as a notebook for later re-use. 

### Using Apache Zeppelin

In a browser window, navigate to <http://dataplatform:28080> and you should see the Apache Zeppelin homepage. 

First let's finish the configuration of the Spark Interpreter. Click on the **anonymous** drop-down menu and select **Interpreter**

![Alt Image Text](./images/zeppelin-interpreter.png "Zeppelin Interpreter")

On the **Interpreters** page, navigate to the **Spark** interpreter. You can also enter `spark` into the search edit field and **Interpreters** will be filtered down to only one single item. 

![Alt Image Text](./images/zeppelin-spark-interpreter.png "Zeppelin Interpreter")

Click on **edit** to change the configuration. 

Navigate to the **Properties** section and enter `1` into the **spark.cores.max** field and `8g` into the **spark.executor.memory** field. 

![Alt Image Text](./images/zeppelin-spark-interpreter2.png "Zeppelin Interpreter")

Then scroll all the way down to the bottom of the settings where you can see a **Dependency** section. Enter `org.apache.commons:commons-lang3:3.5` into the edit field below **artifact** and click **Save**

![Alt Image Text](./images/zeppelin-spark-interpreter3.png "Zeppelin Interpreter")

When asked to restart the interpreter, click **OK**. 

Now let's create a new Notebook to perform some Spark actions. Navigate back to the Zeppelin homepage and click on the **Create new note** link. 

Enter `HelloSpark` into the **Note Name** field and leave the **Default Interpreter** set to **spark** and click **Create**. 

You should be brought forward to an empty notebook with an empty paragraph. Again let's use the `spark.version` command by adding it to the empty cell and hit **Shift** + **Enter** to execute the statement.  

![Alt Image Text](./images/zeppelin-spark-execute-cell.png "Zeppelin Execute Shell")

By default the Spark Zeppelin interpreter will be using the Scala API. To switch to the Python API, use the following directive `%pyspark` at the beginning of the cell. This will be the new default for the interpreter

![Alt Image Text](./images/zeppelin-spark-execute-python.png "Zeppelin Execute Shell")

Zeppelin allows for mixing different interpreters in one and the same Notebook, whereas one interpreter always being the default (the one chosen when creating the notebook, **spark** in our case). 

You can use the `%sh` interpreter to perform shell actions. We can use it for example to perform a hadoop filesystem action using the `hadoop fs` command (if you have HDFS running) or an `s3cmd` to perform an action on Object Storage, if MinIO is running. 

#### Working with HDFS (if installed)

For example to list the files in the `/user/hue/` folder on HDFS, we can perform the following command

```
%sh
hadoop fs -ls hdfs://namenode:9000/user/hue 
```

**Note**: the shell will be executed inside the `zeppelin` container. Therefore to work with HDFS, we have to provide a full HDFS link. 

![Alt Image Text](./images/zeppelin-spark-execute-shell.png "Zeppelin Execute Shell")

#### Working with MinIO (if installed)

To list all the objects within the `flight-bucket

```
%sh
s3cmd ls -r s3://flight-bucket
```

You can use Apache Zeppelin to perform the workshop below. The other option is to use **Jupyter**. 

### Using Jupyter

In a browser window navigate to <http://dataplatform:28888>. 
Enter `abc123` into the **Password or token** field and click **Log in**. 

You should be forwarded to the **Jupyter** homepage. Click on the **Python 3** icon in the **Notebook** section to create a new notebook using the **Python 3** kernel.

![Alt Image Text](./images/jupyter-create-notebook.png "Jupyter Create Notebook")
  
You will be forwarded to an empty notebook with a first empty cell. 

Here you can enter your commands. In contrast to **Apache Zeppelin**, we don't have an active Spark Session at hand. We first have to create one. 

Add the following code to the first cell

```
import os
# make sure pyspark tells workers to use python3 not 2 if both are installed
#os.environ['PYSPARK_PYTHON'] = '/usr/bin/python3'

import pyspark
conf = pyspark.SparkConf()

# point to mesos master or zookeeper entry (e.g., zk://10.10.10.10:2181/mesos)
conf.setMaster("spark://spark-master:7077")

# set other options as desired
conf.set("spark.executor.memory", "8g")
conf.set("spark.executor.cores", "1")
conf.set("spark.core.connection.ack.wait.timeout", "1200")

from pyspark.sql import SparkSession
spark = SparkSession.builder.appName('abc').config(conf=conf).getOrCreate()
sc = spark.sparkContext
```

and execute it by entering **Shift** + **Enter**. 

If you check the code you can see that we connect to the Spark Master and get a session on the "spark cluster", available through the `spark` variable. The Spark Context is available as variable `sc`.

First execute `spark.version` in another shell to show the Spark version in place. 

Also execute a python command `print ("hello")` just to see that you are executing python. 

![Alt Image Text](./images/jupyter-execute-cell.png "Jupyter Execute cell")

You can use Jupyter to perform the workshop. 


## Working with Spark Resilient Distributed Datasets (RDDs)

Spark’s primary core abstraction is called a **Resilient Distributed Dataset** or **RDD**. 

It is a distributed collection of elements that is parallelised across the cluster. In other words, a RDD is an immutable collection of objects that is partitioned and distributed across multiple physical nodes of a YARN cluster and that can be operated in parallel.

There are three methods for creating a RDD:

 1. Parallelise an existing collection. This means that the data already resides within Spark and can now be operated on in parallel. 
 * Create a RDD by referencing a dataset. This dataset can come from any storage source supported by Hadoop such as HDFS, Cassandra, HBase etc.
 * Create a RDD by transforming an existing RDD to create a new RDD.

We will be using the later two methods in this workshop.

First let's upload the data needed for this workshop, using the techniques we have learned in the [HDFS Workshop](../02-hdfs/README.md) when working with HDFS or [Working with MinIO Object Storage](../03-object-storage/README.md) when working with MinIO Object Storage.

The raw data can be downloaded 

### Upload Raw Data to HDFS

In the RDD workshop we are working with text data.

In HDFS under folder `/user/hue` create a new folder `wordcount` and upload the two files into that folder. 

Here are the commands to perform when using the **Hadoop Filesystem Command** on the command line

```
docker exec -ti namenode hadoop fs -mkdir -p /user/hue/wordcount/

docker exec -ti namenode hadoop fs -copyFromLocal /data-transfer/wordcount/big.txt /user/hue/wordcount/

docker exec -ti namenode hadoop fs -ls /user/hue/wordcount/
```

Of course you can also use **Hue** to upload the data as we have learned in the [HDFS Workshop](../02-hdfs/README.md).

### Upload Raw Data to MinIO

First create a bucket for the data

```
docker exec -ti awscli s3cmd mb s3://wordcount-bucket
```

And then copy the `big.txt` into the new bucket 

```
docker exec -ti awscli s3cmd put /data-transfer/wordcount/big.txt s3://wordcount-bucket/raw-data/
```

Now the data is either available in HDFS or MinIO, depending on your environment. Next we will work with the data from Spark RDDs.

### Implement Wordcount using Spark Python API

In this section we will see how Word Count can be implemented using the Spark Python API.

You can use either one of the three different ways described above to access the Spark Python environment. 

Just copy and paste the commands either into the **PySpark** command line or into the paragraphs in **Zeppelin** or **Jupyter**. In Zeppelin you have to switch to Python interpreter by using the following directive `%spark.pyspark` on each paragraph.

In **Jupyter** make sure to get the connection to spark using the script shown before. 

For data in HDFS, perform

```
lines = sc.textFile("hdfs://namenode:9000/user/hue/wordcount/big.txt")
```

and if data is in MinIO object storage, perform

```
lines = sc.textFile("s3a://wordcount-bucket/raw-data/big.txt")
```

Split the line into words and flat map it

```
words = lines.flatMap(lambda line: line.split(" "))
```

Reduce by key to get the counts by word and number

```
counts = words.map(lambda word: (word,1)).reduceByKey(lambda a, b : a + b)
```

Save the counts to a file on HDFS (in folder output) or on MinIO object storage. 

This is an action and will start execution on Spark. Make sure to remove the output folder in case it already exists

to write to HDFS:

```
counts.saveAsTextFile("hdfs://namenode:9000/user/hue/wordcount/result")
```
to write to MinIO object storage:

```
counts.saveAsTextFile("s3a://wordcount-bucket/result-data")
```

To view the number of distinct values in counts.

```
counts.count()
```

To check the results in HDFS or MinIO, perform the following commands. 

For HDFS, do an ls and a cat to display the content: 

```
docker exec -ti namenode hadoop fs -ls hdfs://namenode:9000/user/hue/wordcount/result

docker exec -ti namenode hadoop fs -cat hdfs://namenode:9000/user/hue/wordcount/result/part-00000 | more
```

For MinIO object storage, do an ls to see the result and use the MinIO browser to download the object to the local machine.

```
docker exec -ti awscli s3cmd ls -r s3://wordcount-bucket/result-data
```

This finishes the simple Python implementation of the word count in Spark.
 
## Working with Apache Spark Data Frames

The data needed here has been uploaded to MinIO in workshop 03-object-storage. If there are already loaded, you can skip the next section "(Re-)Upload Raw Data from Workshop 03".
 
### (Re-)Upload Raw Data from Workshop 03

In this workshop we are working with flight data. The files are available in the `data-transfer` folder. 

Airports:

```
docker exec -ti awscli s3cmd put /data-transfer/flight-data/airports.csv s3://flight-bucket/raw-data/airports/airports.csv
```

Plane-Data:

```
docker exec -ti awscli s3cmd put /data-transfer/flight-data/plane-data.csv s3://flight-bucket/raw-data/planes/plane-data.csv
```

Carriers:

```
docker exec -ti awscli s3cmd put /data-transfer/flight-data/carriers.json s3://flight-bucket/raw-data/carriers/carriers.json
```

Flights:

```
docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_4_1.csv s3://flight-bucket/raw-data/flights/

docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_4_2.csv s3://flight-bucket/raw-data/flights/

docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_1.csv s3://flight-bucket/raw-data/flights/

docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_2.csv s3://flight-bucket/raw-data/flights/

docker exec -ti awscli s3cmd put /data-transfer/flight-data/flights-small/flights_2008_5_3.csv s3://flight-bucket/raw-data/flights/
```

### Working with Flighs data using Spark DataFrames

For this workshop we will be using Zeppelin discussed above. 

But you can easily adapt it to use either **PySpark** or **Apache Jupyter**.

In a browser window, navigate to <http://dataplatform:28080> and make sure that you configure the **Spark** Interpreter as discussed above.

Now let's create a new notebook by clicking on the **Create new note** link and set the **Note Name** to `SparkDataFrame` and set the **Default Interpreter** to `spark`. 

Click on **Create Note** and a new Notebook is created with one cell which is empty. 

#### Add some Markdown first

Navigate to the first cell and start with a title. By using the `%md` directive we can switch to the Markdown interpreter, which can be used for displaying static text.

```
%md # Spark DataFrame sample with flights data
```

Click on the **>** symbol on the right or enter **Shift** + **Enter** to run the paragraph.

The markdown code should now be rendered as a Heading-1 title.

#### Working with Airports Data

First add another title, this time as a Heading-2.

```
%md ## Working with the Airport data
```

Now let's work with the Airports data, which we have uploaded to `s3://flight-bucket/raw-data/airports/`. Let's see the data by performing an `%sh` directive

```
%sh
s3cmd ls -r s3://flight-bucket/raw-data/airports/
```

We can see that there is one file for the airports data.

![Alt Image Text](./images/zeppelin-sh-ls-airports.png "Zeppelin Show Files")

Now let’s start using some code. First we have to import the spark python API. 

```
%pyspark
from pyspark.sql.types import *
```

Next let’s import the flights data into a DataFrame and show the first 5 rows. We use header=true to use the header line for naming the columns and specify to infer the schema.  

```
%pyspark
airportsRawDF = spark.read.csv("s3a://flight-bucket/raw-data/airports", 
    	sep=",", inferSchema="true", header="true")
airportsRawDF.show(5)
```

The output will show the header line followed by the 5 data lines.

![Alt Image Text](./images/zeppelin-show-airports-raw.png "Zeppelin Welcome Screen")

Now let’s display the schema, which has been derived from the data:

```	
%pyspark
airportsRawDF.printSchema()
```

You can see that both string as well as double datatypes have been used and that the names of the columns are derived from the header row of the CSV file. 

```
root
 |-- iata: string (nullable = true)
 |-- airport: string (nullable = true)
 |-- city: string (nullable = true)
 |-- state: string (nullable = true)
 |-- country: string (nullable = true)
 |-- lat: double (nullable = true)
 |-- long: double (nullable = true)
``` 
 
Next let’s ask for the total number of rows in the dataset. Should return a total of **3376**. 

```
%pyspark
airportsRawDF.count()
```
 
#### Working with Flights Data

First add another title, this time as a Heading-2.

```
%md ## Working with the Flights data
```

Let’s now start working with the Flights data, which we have uploaded with the various files within the `s3://flight-bucket/raw-data/flights/`.

Navigate to the first cell and start with a title. By using the `%md` directive we can switch to the Markdown interpreter, which can be used for displaying static text.
 
Make sure that the data is in the right place. You can use the directive `%sh` to execute a shell action.

```
%sh
s3cmd ls -r s3://flight-bucket/raw-data/flights/
```

You should see the five files inside the `flights` folder

![Alt Image Text](./images/zeppelin-sh-ls.png "Zeppelin Show Files")

The CSV files in this case do not contain a header line, therefore we can not use the same technique as before with the airports and derive the schema from the header. 

We first have to manually define a schema. One way is to use a DSL as shown in the next code block. 

```
%pyspark
flightSchema = """`year` INTEGER, `month` INTEGER, `dayOfMonth` INTEGER,  `dayOfWeek` INTEGER, `depTime` INTEGER, `crsDepTime` INTEGER, `arrTime` INTEGER, `crsArrTime` INTEGER, `uniqueCarrier` STRING, `flightNum` STRING, `tailNum` STRING, `actualElapsedTime` INTEGER,
                   `crsElapsedTime` INTEGER, `airTime` INTEGER, `arrDelay` INTEGER,`depDelay` INTEGER,`origin` STRING, `dest` STRING, `distance` INTEGER, `taxiIn` INTEGER, `taxiOut` INTEGER, `cancelled` STRING, `cancellationCode` STRING, `diverted` STRING, 
                   `carrierDelay` STRING, `weatherDelay` STRING, `nasDelay` STRING, `securityDelay` STRING, `lateAircraftDelay` STRING"""
```

Now we can import the flights data into a DataFrame using this schema and show the first 5 rows. 

We use  to use the header line for naming the columns and specify to infer the schema. We specify `schema=fligthSchema` to use the schema from above.  

```
%pyspark
flightsRawDF = spark.read.csv("s3a://flight-bucket/raw-data/flights", 
    	sep=",", inferSchema="false", header="false", schema=flightSchema)
flightsRawDF.show(5)
```
	
The output will show the header line followed by the 5 data lines.

![Alt Image Text](./images/zeppelin-show-flights-raw.png "Zeppelin Welcome Screen")

Let’s also see the schema, which is not very surprising

```	
%pyspark
flightsRawDF.printSchema()
```

The result should be a rather large schema only shown here partially. You can see that both string as well as integer datatypes have been used and that the names of the columns are derived from the header row of the CSV file. 

```
root
 |-- year: integer (nullable = true)
 |-- month: integer (nullable = true)
 |-- dayOfMonth: integer (nullable = true)
 |-- dayOfWeek: integer (nullable = true)
 |-- depTime: integer (nullable = true)
 |-- crsDepTime: integer (nullable = true)
 |-- arrTime: integer (nullable = true)
 |-- crsArrTime: integer (nullable = true)
 |-- uniqueCarrier: string (nullable = true)
 |-- flightNum: string (nullable = true)
 |-- tailNum: string (nullable = true)
 |-- actualElapsedTime: integer (nullable = true)
 |-- crsElapsedTime: integer (nullable = true)
 |-- airTime: integer (nullable = true)
 |-- arrDelay: integer (nullable = true)
 |-- depDelay: integer (nullable = true)
 |-- origin: string (nullable = true)
 |-- dest: string (nullable = true)
 |-- distance: integer (nullable = true)
 |-- taxiIn: integer (nullable = true)
 |-- taxiOut: integer (nullable = true)
 |-- cancelled: string (nullable = true)
 |-- cancellationCode: string (nullable = true)
 |-- diverted: string (nullable = true)
 |-- carrierDelay: string (nullable = true)
 |-- weatherDelay: string (nullable = true)
 |-- nasDelay: string (nullable = true)
 |-- securityDelay: string (nullable = true)
 |-- lateAircraftDelay: string (nullable = true)
```
	
Next let’s ask for the total number of rows in the dataset. Should return **50'000**. 

```
%pyspark
flightsRawDF.count()
```
	
You can also transform data easily into another format, just by writing the DataFrame out to a new file or object. 

Let’s create a JSON representation of the data. We will write it to a refined folder. 

For HDFS:

```
%pyspark
flightsRawDF.write.json("hdfs://namenode:9000/user/hue/refined-data/flights")
```
	
For MinIO:

```
%pyspark
flightsRawDF.write.json("s3a://flight-bucket/refined-data/flights")
```
	
	
Should you want to execute it a 2nd time, then you first have to delete the output folder, otherwise the 2nd execution will throw an error. 

You can directly execute the remove from within Zeppelin, using the `%sh` directive. 

For HDFS:

```
%sh
hadoop fs -rm -R hdfs://namenode:9000/user/hue/refined-data/flights
```
	
For MinIO:

```
%sh
s3cmd rm -r s3://flight-bucket/refined-data/flights
```
	
By now we have imported the airports and flights data and made it available as a Data Frame. 

Additionally we have also stored the data to a file in json format. 




