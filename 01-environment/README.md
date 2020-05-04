# Data Platform on Docker

## Provisioning environment
The environment for this course is completely based on docker containers. 

In order to simplify the provisioning, a single docker-compose configuration is used. All the necessary software will be provisioned using Docker. 

You have the following options to start the environment:

 * [**Local Virtual Machine Environment**](./LocalVirtualMachine.md) - a Virtual Machine with Docker and Docker Compose pre-installed will be distributed at by the course infrastructure. You will need 50 GB free disk space.
 * [**Local Docker Environment**](./LocalDocker.md) - you have a local Docker and Docker Compose setup in place which you want to use
 * [**AWS Lightsail Environment**](./Lightsail.md) - AWS Lightsail is a service in Amazon Web Services (AWS) with which we can easily startup an environment and provide all the necessary bootstrapping as a script.


## Post Provisioning

These steps are necessary after the starting the docker environment. 

### Add entry to local /etc/hosts File
To simplify working with the Data Platform and for the links below to work, add the following entry to your local `/etc/hosts` file. 

```
40.91.195.92	dataplatform
```

Replace the IP address by the PUBLIC IP of the docker host. 

## Services accessible on Data Platform
The following service are available as part of the platform:

Product | Type | Service | Url | Url (local)
------|------| --------| ----- | ----------
Zepplin | Development | Zeppelin | <http://dataplatform:28080> | <http://localhost:28080>
Jupyter | Development | Jupyter | <http://dataplatform:28888> | <http://localhost:28888>
Nifi | Development | Nifi | <http://dataplatform:18080> | <http://localhost:18080/>
Streamsets Data Collector | Development | Streamsets | <http://dataplatform:18630> | <http://localhost:18630/>
Streamsets Transformer | Development | Streamsets Transformer | <http://dataplatform:19630> | <http://localhost:19630/>
Spark UI | Management  | Spark | <http://dataplatform:8080> | <http://localhost:8080>
Spark History Server UI | Management | Spark | <http://dataplatform:28117> | <http://localhost:28117>
Presto | BigData SQL | Presto | <http://dataplatform:28081>| <http://localhost:28081>
Dremio | BigData SQL | Dremio | <http://dataplatform:9047>| <http://localhost:9047>
CMAK | Management | Kafka | <http://dataplatform:28104>| <http://localhost:28104>
AKHQ | Management | Kafka | <http://dataplatform:28107>| <http://localhost:28107>
Minio UI | Management | Minio | <http://dataplatform:9000>| <http://localhost:9000>
Airflow | Management | Airflow UI | <http://dataplatform:28139>| <http://localhost:28139>

