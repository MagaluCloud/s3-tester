# import functions: wait_command
Include ./spec/019_utils.sh
is_variable_null() {
  [ -z "$1" ]
}

Describe 'Unique bucket:' category:"BucketManagement" category:"quick"
  setup(){
    bucket_name="test-090-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"090"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    id=$(aws s3api --profile $profile-second list-buckets | jq -r '.Owner.ID')
    Skip if "No such a "$profile-second" user" is_variable_null "$id"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile $profile s3api create-bucket --bucket $test_bucket_name
      The error should include "BucketAlreadyExists"
      The status should be failure
      ;;
    "aws-s3")
      When run aws --profile $profile s3 mb s3://$test_bucket_name
      The error should include "BucketAlreadyExists"
      The status should be failure
      ;;
    "rclone")
      When run rclone mkdir $profile:$test_bucket_name -vv --dump-headers
      The error should include "409 Conflict"
      The status should be success
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage buckets create $test_bucket_name --raw"
      # When run mgc object-storage buckets create $test_bucket_name --raw
      The stdout should include "BucketAlreadyExists"
      The status should be failure
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End
