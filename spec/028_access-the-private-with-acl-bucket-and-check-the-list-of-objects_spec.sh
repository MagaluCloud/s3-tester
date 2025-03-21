is_variable_null() {
  [ -z "$1" ]
}

Describe 'Access the Private with ACL bucket with and check the list of objects:' category:"BucketPermission" category:"quick"
  setup(){
    bucket_name="test-028-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"028"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    id=$(aws s3api --profile $profile-second list-buckets | jq -r '.Owner.ID')
    Skip if "No such a "$profile-second" user" is_variable_null "$id"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws --profile $profile s3api wait bucket-exists --bucket $test_bucket_name
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null
    aws --profile $profile s3api wait object-exists --key $file1_name --bucket $test_bucket_name
    aws s3api --profile $profile put-bucket-acl --bucket $test_bucket_name --grant-read id=$id > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run bash ./spec/retry_command.sh "aws --profile $profile-second s3api list-objects-v2 --bucket $test_bucket_name"
    # When run aws --profile $profile-second s3api list-objects-v2 --bucket $test_bucket_name
    The output should include "$file1_name"
      ;;
    "rclone")
    When run bash ./spec/retry_command.sh "rclone ls $profile-second:$test_bucket_name"
    # When run rclone ls $profile-second:$test_bucket_name
    The output should include "$file1_name"
      ;;
    "mgc")
      mgc workspace set $profile-second > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage objects list $test_bucket_name --raw"
      #When run mgc object-storage objects list $test_bucket_name --raw
      The status should be success
      The output should include "$file1_name"
      ;;
    esac
    The status should be success
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
    aws s3api wait bucket-not-exists --bucket $test_bucket_name --profile $profile
  End
End
