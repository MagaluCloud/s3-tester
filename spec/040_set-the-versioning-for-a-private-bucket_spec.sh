Describe 'Set the versioning for a private bucket:' category:"ObjectVersioning" category:"quick"
  setup(){
    bucket_name="test-040-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"040"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run aws s3api --profile $profile put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled
    The output should include ""
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
    mgc workspace set $profile > /dev/null
    When run bash ./spec/retry_command.sh "mgc object-storage buckets versioning enable $test_bucket_name --raw"
    # When run mgc object-storage buckets versioning enable $test_bucket_name --raw
    The output should include "$test_bucket_name"
      ;;
    esac
    The status should be success
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
  End
End
