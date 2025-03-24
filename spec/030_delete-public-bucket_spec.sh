Describe 'Delete public bucket:' category:"BucketPermission" category:"quick"
  setup(){
    bucket_name="test-030-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"030"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3api create-bucket --bucket $test_bucket_name --acl public-read > /dev/null
    aws --profile $profile s3api wait bucket-exists --bucket $test_bucket_name
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run aws --profile $profile s3 rb s3://$test_bucket_name --force
    The output should include "$test_bucket_name"
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
    bash ./spec/retry_command.sh  "aws s3api wait bucket-not-exists --bucket $test_bucket_name --profile $profile"
  End
End
