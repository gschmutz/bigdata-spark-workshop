# bigdata-minio-platform - List of Services

| Service | Links | External<br>Port | Internal<br>Port | Description
|--------------|------|------|------|------------
|[airflow](./documentation/services/airflow )|[Web UI](http://192.168.1.112:28139) - [Rest API](http://192.168.1.112:28139/api/v1/dags)|28139<br>|8080<br>|Job Orchestration & Scheduler
|[airflow-db](./documentation/services/airflow )||||Job Orchestration & Scheduler
|[airflow-scheduler](./documentation/services/airflow )||||Job Orchestration & Scheduler
|[avro-tools](./documentation/services/avro-tools )||||Avro Tools
|[awscli](./documentation/services/awscli )||||AWS CLI
|[filebrowser](./documentation/services/filebrowser )|[Web UI](http://192.168.1.112:28178/filebrowser)|28178<br>|8080<br>|File-Browser
|[hive-metastore](./documentation/services/hive-metastore )||9083<br>|9083<br>|Hive Metastore
|[hive-metastore-db](./documentation/services/hive-metastore )||5442<br>|5432<br>|Hive Metastore DB
|[jupyter](./documentation/services/jupyter )|[Web UI](http://192.168.1.112:28888)|28888<br>28376-28380<br>|8888<br>4040-4044<br>|Web-based interactive development environment for notebooks, code, and data
|[markdown-viewer](./documentation/services/markdown-viewer )|[Web UI](http://192.168.1.112:80)|80<br>|3000<br>|Platys Platform homepage viewer
|[minio-1](./documentation/services/minio )|[Web UI](http://192.168.1.112:9010)|9000<br>9010<br>|9000<br>9010<br>|Software-defined Object Storage
|[minio-mc](./documentation/services/minio )||||MinIO Console
|[nifi2-1](./documentation/services/nifi )|[Web UI](https://192.168.1.112:18083/nifi) - [Rest API](https://192.168.1.112:18083/nifi-api)|18083<br>10015<br>1273<br>|18083<br>10015/tcp<br>1234<br>|NiFi Data Integration Engine (V2)
|[parquet-tools](./documentation/services/parquet-tools )||||Parquet Tools
|[postgresql](./documentation/services/postgresql )||5432<br>|5432<br>|Open-Source object-relational database system
|[spark-history](./documentation/services/spark-historyserver )|[Web UI](http://192.168.1.112:28117) - [Rest API](http://192.168.1.112:28117/api/v1)|28117<br>|18080<br>|Spark History Server
|[spark-master](./documentation/services/spark )|[Web UI](http://192.168.1.112:28304)|28304<br>6066<br>7077<br>4040-4044<br>|28304<br>6066<br>7077<br>4040-4044<br>|Spark Master Node
|[spark-thriftserver](./documentation/services/spark-thriftserver )|[Web UI](http://192.168.1.112:28298)|28118<br>28298<br>|10000<br>4040<br>|Spark Thriftserver
|[spark-worker-1](./documentation/services/spark )||28111<br>|28111<br>|Spark Worker Node
|[spark-worker-2](./documentation/services/spark )||28112<br>|28112<br>|Spark Worker Node
|[trino-1](./documentation/services/trino )|[Web UI](http://192.168.1.112:28082/ui/preview)|28082<br>28083<br>|8080<br>8443<br>|SQL Virtualization Engine
|[wetty](./documentation/services/wetty )|[Web UI](http://192.168.1.112:3001)|3001<br>|3000<br>|A terminal window in Web-Browser
|[zeppelin](./documentation/services/zeppelin )|[Web UI](http://192.168.1.112:28080)|28080<br>6060<br>5050<br>4050-4054<br>|8080<br>6060<br>5050<br>4050-4054<br>|Data Science Notebook|

**Note:** init container ("init: true") are not shown