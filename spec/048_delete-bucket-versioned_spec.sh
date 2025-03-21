Describe 'Delete Bucket versioned:' category:"ObjectVersioning" category:"quick"
  setup(){
    bucket_name="test-048-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"048"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3api create-bucket --bucket $test_bucket_name > /dev/null
    aws s3api --profile $profile put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run aws --profile $profile s3 rb s3://$test_bucket_name --force
    The output should include ""
      ;;
    "rclone")
    When run rclone rmdir $profile:$test_bucket_name
    The output should include ""
      ;;
    "mgc")
    mgc workspace set $profile > /dev/null
    When run bash ./spec/retry_command.sh "mgc object-storage buckets delete $test_bucket_name --no-confirm --raw"
    # When run mgc object-storage buckets delete $test_bucket_name --no-confirm --raw
    The output should include ""
      ;;
    esac
    The status should be success
  End
End
