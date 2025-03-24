is_variable_null() {
  [ -z "$1" ]
}

Describe 'Create a ACL read for a bucket:' category:"BucketPermission" category:"quick"
  setup(){
    bucket_name="test-023-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"023"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    id=$(aws s3api --profile $profile-second list-buckets | jq -r '.Owner.ID')
    Skip if "No such a "$profile-second" user" is_variable_null "$id"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws --profile $profile s3api wait bucket-exists --bucket $test_bucket_name
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws s3api --profile $profile put-bucket-acl --bucket $test_bucket_name --grant-read id=$id
      The output should include ""
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage buckets acl set --grant-read id=$id --dst $test_bucket_name --raw"
      # When run mgc object-storage buckets acl set --grant-read id=$id --dst $test_bucket_name --raw
      The output should include ""
      ;;
    esac
    The status should be success
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
    aws s3api wait bucket-not-exists --bucket $test_bucket_name --profile $profile
  End
End
