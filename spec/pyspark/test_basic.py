# make sure there is an AWS_PROFILE env var set and a configured aws profile with the name
from pyspark.sql import SparkSession

def test_pyspark_session():
    spark = SparkSession.builder.appName("foo").getOrCreate()
    assert True

if __name__ == "__main__":
    pytest.main([__file__])

