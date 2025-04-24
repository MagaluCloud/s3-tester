import boto3
from pyspark.sql import SparkSession
from pyspark.sql import Row
from datetime import datetime, date
import os
import pytest

# os.environ['JAVA_HOME'] = '/usr/lib/jvm/java-17-openjdk-amd64'

session = boto3.Session()
credentials = session.get_credentials().get_frozen_credentials()

s3_endpoint_url = 'https://br-se1.magaluobjects.com'

s3 = boto3.client('s3')
def get_spark_session(path_style_access=True):
    try:
        builder = SparkSession.builder.appName("Demo") \
            .config("spark.jars.packages", "org.apache.hadoop:hadoop-aws:3.3.1,com.amazonaws:aws-java-sdk-pom:1.12.365") \
            .config("spark.hadoop.fs.s3a.access.key", credentials.access_key) \
            .config("spark.hadoop.fs.s3a.secret.key", credentials.secret_key) \
            .config("spark.hadoop.fs.s3a.endpoint", s3_endpoint_url) \
            .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
            .config("spark.hadoop.fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider") \
            .config("spark.hadoop.fs.s3a.path.style.access", "true" if path_style_access else "false")

        spark = builder.getOrCreate()
        print("Sessão Spark criada com sucesso.")
        return spark
    except Exception as e:
        print(f"Erro ao criar a sessão Spark: {str(e)}")
        return None

@pytest.fixture(scope="session")
def spark_path_style():
    spark = get_spark_session(path_style_access=True)
    if spark:
        spark.sparkContext.setLogLevel("DEBUG")
    yield spark
    if spark:
        spark.stop()

@pytest.fixture(scope="session")
def spark_vhost_style():
    spark = get_spark_session(path_style_access=False)
    if spark:
        spark.sparkContext.setLogLevel("DEBUG")
    yield spark
    if spark:
        spark.stop()

def test_write_and_read_from_s3_path_style(spark_path_style):
    if spark_path_style:
        _test_write_and_read_from_s3(spark_path_style, "s3a://hadoop/teste-parquet-path")
    else:
        pytest.fail("Sessão Spark não foi criada.")

def test_write_and_read_from_s3_vhost_style(spark_vhost_style):
    if spark_vhost_style:
        _test_write_and_read_from_s3(spark_vhost_style, "s3a://hadoop/teste-parquet-vhost")
    else:
        pytest.fail("Sessão Spark não foi criada.")

def _test_write_and_read_from_s3(spark, s3_path):
    # Criar um DataFrame
    df = spark.createDataFrame([
        Row(a=1, b=2.0, c='string1', d=date(2000, 1, 1), e=datetime(2000, 1, 1, 12, 0)),
        Row(a=2, b=3.0, c='string2', d=date(2000, 2, 1), e=datetime(2000, 1, 2, 12, 0)),
        Row(a=4, b=5.0, c='string3', d=date(2000, 3, 1), e=datetime(2000, 1, 3, 12, 0))
    ])

    # Escrever o DataFrame no S3
    try:
        df.write.parquet(s3_path, mode="overwrite")
        print("Dados escritos com sucesso.")
    except Exception as e:
        print(f"Erro ao escrever dados: {str(e)}")
        assert False, f"Erro ao escrever dados: {str(e)}"

    # Verificar se os dados foram escritos no S3
    prefix = s3_path.split(f's3a://hadoop/')[1]

    s3 = session.resource('s3', endpoint_url=s3_endpoint_url)
    bucket = s3.Bucket("hadoop")

    objects = list(bucket.objects.filter(Prefix=prefix))
    assert len(objects) > 0, "Nenhum objeto encontrado no bucket."

    print("Objetos no bucket:")
    for obj in objects:
        print(obj.key)

    # Ler os dados de volta do S3 e verificar o conteúdo
    read_df = spark.read.parquet(s3_path)
    read_df.show()
    assert read_df.count() == df.count(), "A contagem de registros não corresponde."
    assert read_df.columns == df.columns, "As colunas não correspondem."

# Execute os testes
if __name__ == "__main__":
    pytest.main([__file__])
