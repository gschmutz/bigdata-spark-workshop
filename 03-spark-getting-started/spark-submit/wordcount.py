import sys
from pyspark import SparkConf
from pyspark.sql import SparkSession
from pyspark.sql.functions import split
from pyspark.sql.functions import explode, col
from pyspark.sql.functions import lower 
from pyspark.sql.functions import regexp_extract 

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: wordcount <s3-endpoint> <s3-object-url> <aws-access-key> <aws-secret-key>", file=sys.stderr)
        sys.exit(-1)

    print(sys.argv[1])
    print(sys.argv[2])
    print(sys.argv[3])
    print(sys.argv[4])
    
    conf = SparkConf()
    conf.set('spark.hadoop.fs.s3a.impl', 'org.apache.hadoop.fs.s3a.S3AFileSystem')
    conf.set('spark.hadoop.fs.s3a.endpoint', sys.argv[1])
    conf.set('spark.hadoop.fs.s3a.access.key', sys.argv[3])
    conf.set('spark.hadoop.fs.s3a.secret.key', sys.argv[4])
    conf.set('spark.hadoop.fs.s3a.path.style.access', True)
    conf.set('spark.hadoop.fs.s3a.aws.credentials.provider', 'org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider')
    conf.set('spark.jars.packages', 'org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262')

    spark = SparkSession\
        .builder\
        .config(conf=conf)\
        .appName("PythonWordCount")\
        .getOrCreate()

    bookDF = spark.read.text(sys.argv[2])
    
    linesDF = bookDF.select(split(bookDF.value, " ").alias("line"))
    wordsDF = linesDF.select(explode(col("line")).alias("word"))
    wordsLowerDF = wordsDF.select(lower(col("word")).alias("word_lower"))
    wordsCleanDF = wordsLowerDF.select( regexp_extract(col("word_lower"), "[a-z]*", 0).alias("word") )
    wordsNonNullDF = wordsCleanDF.where(col("word") != "")
    resultsDF = wordsNonNullDF.groupby(col("word")).count()
    
    resultsDF.orderBy("count", ascending=False).show(10)

    spark.stop()