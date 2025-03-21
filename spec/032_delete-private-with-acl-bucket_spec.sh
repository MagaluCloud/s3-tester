is_variable_null() {
  [ -z "$1" ]
}

Describe 'Delete private with ACL bucket:' category:"BucketPermission" category:"quick"
  setup(){
    bucket_name="test-032-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"032"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    id=$(aws s3api --profile $profile-second list-buckets | jq -r '.Owner.ID')
    Skip if "No such a "$profile-second" user" is_variable_null "$id"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws --profile $profile s3api wait bucket-exists --bucket $test_bucket_name
    aws s3api --profile $profile put-bucket-acl --bucket $test_bucket_name --grant-read id=$id > /dev/null
    case "$client" in
    "aws" | "aws-s3")
    When run aws --profile $profile s3 rb s3://$test_bucket_name --force
    The output should include "$test_bucket_name"
      ;;
    "aws-s3api")
    When run aws --profile $profile s3api delete-bucket --bucket $test_bucket_name --debug
    The error should include "$test_bucket_name HTTP/1.1\" 204 0"
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
    aws s3api wait bucket-not-exists --bucket $test_bucket_name --profile $profile
  End
End
