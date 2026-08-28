# Big Data and Spark Workshop

Big Data Workshops with hands-on tutorials for working with S3, Spark, Delta Lake, Trino, ...

This workshop is used in the [Big Data and Spark Ecosystem Module of the Data Engineering CAS](https://www.bfh.ch/ti/de/weiterbildung/cas/big-data/) at the Berner Fachhochschule.

All the workshops can be done on a container-based infrastructure using Docker Compose for the container orchestration. It can be run on a local machine or in a cloud environment. Check [00-environment](./00-environment) for instructions on how to setup the infrastructure.

## Workshops

| # | Workshop | Description |
|---|----------|-------------|
| 1a | [Working with MinIO Object Storage](./01a-minio-object-storage) | Create buckets, upload files (CSV, JSON, PDF), and browse objects using the MinIO Console, `mc`, and `s3cmd`. Establish the shared S3-compatible storage used by all other workshops. |
| 1b | [Working with RustFS Object Storage](./01b-rustfs-object-storage) | Create buckets, upload files (CSV, JSON, PDF), and browse objects using the RustFS Console, `mc`, and `s3cmd`. Establish the shared S3-compatible storage used by all other workshops. |
| 2 | [Working with Amazon S3 Object Storage (optional)](./02-aws-object-storage) | Create S3 buckets, upload data, query structured files in-place with S3 Select, and create IAM programmatic credentials for external access. Requires an AWS subscription. |
| 3 | [Getting Started using Spark RDD and DataFrames](./03-spark-getting-started) | Access Spark via PySpark CLI, Zeppelin, and Jupyter. Implement a word count using the RDD API, then rewrite it using the DataFrame API to understand the difference between transformations and actions. |
| 4 | [Data Reading and Writing using DataFrames](./04-spark-dataframe) | Read CSV and JSON files from MinIO into DataFrames, apply joins and aggregations using the DataFrame API and Spark SQL, write partitioned output, and expose results via the Spark Thrift Server. |
| 5 | [Creating and running a self-contained Spark Application](./05-spark-application) | Package a PySpark transformation pipeline as a standalone Python script with `argparse`, then submit it to the Spark cluster using `spark-submit`. |
| 5a | [Running a Spark Application via Spark Connect](./05a-spark-application-via-spark-connect) | Run the same flight-data transformation as Workshop 5 as a plain Python script using Spark Connect, without `spark-submit` or `docker exec`. The client connects remotely over gRPC and the server handles all cluster and S3 configuration. |
| 6 | [Working with different data types](./06-data-types) | Read and write data in CSV, JSON, Avro, Parquet, and ORC formats, comparing schema inference, compression, and read performance across row-based and columnar formats. |
| 7 | [Working with the Delta Lake Table Format](./07-spark-deltalake) | Write airport data as a Delta Lake table, perform INSERT/UPDATE/DELETE with ACID guarantees, query earlier versions with time travel, compact small files, and vacuum old snapshots. |
| 7a | [Working with the Apache Iceberg Table Format](./07a-spark-iceberg) | Write airport data as an Apache Iceberg table, perform DML operations, inspect snapshot metadata in MinIO, query historical versions with time travel, and compact data files. |
| 8 | [Graph Analysis using Spark GraphFrames](./08-spark-graphframe) | Model airports as vertices and flights as edges, then run graph queries including degree analysis, subgraph filtering, motif finding, PageRank, connected components, shortest paths, and BFS. |
| 9 | [Working with Trino](./09-sql-on-bigdata-with-trino) | Register refined flight data in the Hive Metastore and query it from Trino using standard SQL, including built-in functions, UDFs, relational database federation, and cross-source query federation. |
| 10 | [Data Ingestion with Apache NiFi](./10-data-ingestion-with-nifi) | Build a NiFi data flow using GetFile and PutS3Object processors to automatically ingest flight data files from a local landing zone into MinIO as they arrive. |
| 10a | [Data Ingestion with dlt](./10a-data-ingestion-with-dlt) | Use the Python-native dlt library to ingest the same flight data from a local landing zone into MinIO, with automatic schema inference, Parquet output, and built-in incremental state tracking. |
| 11a | [Job Scheduling with Airflow 3.x](./11a-scheduling-with-airflow-3.x) | Author an Airflow 3.x DAG that uploads raw data to MinIO and submits a Spark job using the SparkSubmitOperator, then monitor and trigger the pipeline from the Airflow UI. |
| 11b | [Job Scheduling with Airflow 2.x](./11b-scheduling-with-airflow-2.x) | Same pipeline as 11a adapted for Airflow 2.x syntax and operators. Note: the current data platform runs Airflow 3.x — use this workshop only with a dedicated Airflow 2.x environment. |
| 12 | [Working with dbt and Spark](./12-dbt-spark) | Build a layered dbt project (raw → prepared → refined) on top of Spark, covering models, materialization strategies, generic tests, incremental models, documentation, and the MetricFlow semantic layer. |

