Describe 'Access the private bucket and check the list of objects:' category:"BucketPermission" category:"quick"
  setup(){
    bucket_name="test-022-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"022"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws --profile $profile s3api wait bucket-exists --bucket $test_bucket_name
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null
    aws --profile $profile s3api wait object-exists --key $file1_name --bucket $test_bucket_name
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run aws --profile $profile-second s3api list-objects-v2 --bucket $test_bucket_name
    The stderr should include "An error occurred (AccessDenied) when calling the ListObjectsV2 operation: Access Denied."
    ;;
    "rclone")
    When run rclone ls $profile-second:$test_bucket_name
    The stderr should include "403"
    ;;
    "mgc")
      mgc workspace set $profile-second > /dev/null
      #When run bash ./spec/retry_command.sh "mgc object-storage objects list --dst $test_bucket_name --raw"
      When run mgc object-storage objects list --dst $test_bucket_name --raw
      #The output should include "403"
      The stderr should include "403"
    ;;
    esac
    The status should be failure
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
  End
End
