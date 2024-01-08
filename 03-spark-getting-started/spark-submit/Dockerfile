FROM trivadis/spark-template-python:3.5.0
	  
COPY wordcount.py /app/

ENV SPARK_APPLICATION_PYTHON_LOCATION /app/wordcount.py
ENV SPARK_APPLICATION_ARGS "http://myplatys-minio.default.svc.cluster.local:9000 s3a://test-bucket/data/README.md admin abc123abc123!"
