Describe 'Delete object with versions:' category:"Skip" category:"quick"
  setup(){
    bucket_name="test-049-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"049"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3api create-bucket --bucket $test_bucket_name > /dev/null
    aws s3api --profile $profile put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null
    aws --profile $profile s3 cp $file1_name  s3://$test_bucket_name > /dev/null
    aws --profile $profile s3 cp $file1_name  s3://$test_bucket_name > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run bash ./spec/retry_command.sh "aws --profile $profile s3 rm s3://$test_bucket_name/$file1_name"
    The output should include "delete"
      ;;
    "rclone")
    When run bash ./spec/retry_command.sh "rclone delete $profile:$test_bucket_name/$file1_name"
    The output should include ""
      ;;
    "mgc")
    mgc workspace set $profile > /dev/null
    When run bash ./spec/retry_command.sh "mgc object-storage objects delete --dst $test_bucket_name/$file1_name --no-confirm --raw"
    # When run mgc object-storage objects delete --dst $test_bucket_name/$file1_name --no-confirm --raw
    The output should include ""
      ;;
    esac
    The status should be success
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
  End
End
