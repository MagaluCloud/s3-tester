Include ./spec/019_utils.sh
is_variable_null() {
  [ -z "$1" ]
}

Describe 'Create a ACL read/write for a bucket:' category:"BucketPermission" category:"quick"
  setup(){
    bucket_name="test-026-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"026"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    id=$(aws s3api --profile $profile-second list-buckets | jq -r '.Owner.ID')
    Skip if "No such a "$profile-second" user" is_variable_null "$id"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    # wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run aws s3api --profile $profile put-bucket-acl --bucket $test_bucket_name --grant-write id=$id --grant-read id=$id
    The output should include ""
      ;;
    "rclone")
    Skip "Skipped test to $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      #Skip "Skipped test to $client"
      When run bash ./spec/retry_command.sh "mgc object-storage buckets acl set --grant-read id=$id --grant-write id=$id --dst $test_bucket_name --raw"
      #When run mgc object-storage buckets acl set --grant-read id=$id --grant-write id=$id --dst $test_bucket_name --raw
      The output should include ""
      ;;
    esac
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
    # wait_command bucket-not-exists $profile "$test_bucket_name"
    The status should be success
  End
End

Describe 'Validate a ACL write for a bucket:' category:"BucketPermission"
  setup(){
    bucket_name="test-026-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"026"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    id=$(aws s3api --profile $profile-second list-buckets | jq -r '.Owner.ID')
    Skip if "No such a "$profile-second" user" is_variable_null "$id"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    # wait_command bucket-exists $profile "$test_bucket_name"
    aws --profile $profile s3api put-bucket-acl --bucket $test_bucket_name --grant-write id=$id
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run bash ./spec/retry_command.sh "aws --profile $profile-second s3 cp $file1_name s3://$test_bucket_name"
    # When run aws --profile $profile-second s3 cp $file1_name s3://$test_bucket_name
    The output should include "upload: ./$file1_name to s3://$test_bucket_name/$file1_name"
      ;;
    "rclone")
    Skip "Skipped test to $client"
      ;;
    "mgc")
      #Skip "Skipped test to $client"
      mgc workspace set $profile-second > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage objects upload $file1_name --dst $test_bucket_name --raw"
      # When run mgc object-storage objects upload $file1_name --dst $test_bucket_name --raw
      The output should include "$file1_name"
      The output should include "$test_bucket_name/$file1_name"
      ;;
    esac
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
    # wait_command bucket-not-exists $profile "$test_bucket_name"
    The status should be success
  End
End
