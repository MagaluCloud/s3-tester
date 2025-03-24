is_variable_null() {
  [ -z "$1" ]
}

Describe 'Set a presigned URL for a private with ACL bucket:' category:"BucketSharing" category:"quick"
  setup(){
    bucket_name="test-037-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"037"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    id=$(aws s3api --profile $profile-second list-buckets | jq -r '.Owner.ID')
    Skip if "No such a "$profile-second" user" is_variable_null "$id"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws s3api --profile $profile put-bucket-acl --bucket $test_bucket_name --grant-write id=$id --grant-read id=$id > /dev/null
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run aws --profile $profile s3 presign s3://$test_bucket_name/$file1_name
    The status should be success
    The output should include X-Amz-Algorithm
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
    mgc workspace set $profile > /dev/null
    When run bash ./spec/retry_command.sh "mgc object-storage objects presign --dst $test_bucket_name/$file1_name --expires-in "5m" --raw"
    # When run mgc object-storage objects presign --dst $test_bucket_name/$file1_name --expires-in "5m" --raw
    The status should be success
    The output should include X-Amz-Algorithm
      ;;
    esac
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
  End
End
