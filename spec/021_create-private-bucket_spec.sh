# import functions: wait_command
Include ./spec/019_utils.sh

Describe 'Create private bucket:' category:"BucketPermission" category:"quick"
  setup(){
    bucket_name="test-021-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"021"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile $profile s3api create-bucket --bucket $test_bucket_name
      The output should include "\"Location\": \"/$test_bucket_name\""
      ;;
    "aws-s3")
      When run aws --profile $profile s3 mb s3://$test_bucket_name
      The output should include "make_bucket: $test_bucket_name"
      ;;
    "rclone")
      When run rclone mkdir $profile:$test_bucket_name -v
      The error should include "Bucket \"$test_bucket_name\" created"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage buckets create $test_bucket_name --raw"
      #When run mgc object-storage buckets create $test_bucket_name --raw
      The output should include "$test_bucket_name"
      ;;
    esac
    The status should be success
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End
