"""
Airflow DAG to submit Apache Spark applications using
`SparkSubmitOperator`, `SparkJDBCOperator` and `SparkSqlOperator`.
"""
import airflow
import os
from datetime import timedelta
from datetime import datetime
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator 
from airflow.providers.amazon.aws.transfers.local_to_s3 import (
    LocalFilesystemToS3Operator,
)
from airflow.providers.amazon.aws.operators.s3 import (
    S3CopyObjectOperator,
    S3DeleteObjectsOperator,
)
from airflow.providers.amazon.aws.operators.s3 import S3DeleteObjectsOperator
from airflow.providers.amazon.aws.hooks.s3 import S3Hook

default_args = {
 'owner': 'airflow',
 'depends_on_past': False,
 'start_date': datetime.now(),
 'catchup': False,
 'retries':1,
 'retry_delay': timedelta(minutes=1),    
}

def upload_local_folder_to_s3(local_folder, s3_bucket, s3_prefix, aws_conn_id):
    s3_hook = S3Hook(aws_conn_id=aws_conn_id)
    for root, dirs, files in os.walk(local_folder):
        for file in files:
            local_file_path = os.path.join(root, file)
            relative_path = os.path.relpath(local_file_path, local_folder)
            s3_key = os.path.join(s3_prefix, relative_path)
            s3_hook.load_file(
                filename=local_file_path,
                key=s3_key,
                bucket_name=s3_bucket,
                replace=True,
            )

with DAG(
 dag_id='spark_airport_and_flight_refined',
 default_args=default_args,
 schedule='@daily',
 tags=['cas-dataengineering'],
) as dag:

    delete_raw_folder_task = S3DeleteObjectsOperator(
        task_id='delete_raw_folder',
        bucket='flight-bucket',
        prefix='raw/',
        aws_conn_id='aws-s3'
    )
    delete_refined_folder_task = S3DeleteObjectsOperator(
        task_id='delete_refined_folder',
        bucket='flight-bucket',
        prefix='refined/',
        aws_conn_id='aws-s3'
    )

    upload_airports_local_to_s3_task = LocalFilesystemToS3Operator(
        task_id="upload_airports_local_to_s3_job",
        filename="/data-transfer/airports-data/airports.csv",
        dest_key="raw/airports/airports.csv",
        dest_bucket="flight-bucket",
        aws_conn_id="aws-s3",
        replace=True,
    )

    upload_flights_local_folder_to_s3_task = PythonOperator(
        task_id='upload_flights_local_folder_to_s3',
        python_callable=upload_local_folder_to_s3,
        op_kwargs={
            'local_folder': '/data-transfer/flight-data/flights-small/',
            's3_bucket': 'flight-bucket',
            's3_prefix': 'raw/flights/',
            'aws_conn_id': 'aws-s3',
        },
    )

    spark_submit_task = SparkSubmitOperator(
        task_id='spark_submit_task',
        conn_id='spark-cluster',
        application='s3a://flight-bucket/app/prep_refined.py',
        name='Airports and Flight Refinement application',
        application_args=[
            '--s3-bucket', 'flight-bucket',
            '--s3-raw-path', 'raw',
            '--s3-refined-path', 'refined'
        ],
    )    

    delete_raw_folder_task >> delete_refined_folder_task >> upload_airports_local_to_s3_task >> upload_flights_local_folder_to_s3_task >> spark_submit_task
