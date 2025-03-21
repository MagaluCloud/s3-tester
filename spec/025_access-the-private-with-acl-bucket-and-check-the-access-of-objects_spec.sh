is_variable_null() {
  [ -z "$1" ]
}

Describe 'Access the Private with ACL bucket and check the access of objects:' category:"BucketPermission" category:"quick"
  setup(){
    bucket_name="test-025-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"025"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    id=$(aws s3api --profile $profile-second list-buckets | jq -r '.Owner.ID')
    Skip if "No such a "$profile-second" user" is_variable_null "$id"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws --profile $profile s3api wait bucket-exists --bucket $test_bucket_name
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null
    aws --profile $profile s3api wait object-exists --key $file1_name --bucket $test_bucket_name
    aws s3api --profile $profile put-bucket-acl --bucket $test_bucket_name --grant-read id=$id --grant-write id=$id > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run aws --profile $profile-second s3api get-object --bucket $test_bucket_name --key $file1_name $file1_name-2
    The status should be failure
    The stderr should include "An error occurred (AccessDenied) when calling the GetObject operation: Access Denied."
      ;;
    "rclone")
    When run rclone -v copy $profile-second:$test_bucket_name/$file1_name $file1_name-2
    The status should be success
    The error should include "There was nothing to transfer"
    # todo: its true if where dont have access the status is success but dont make download? test in other providers
      ;;
    "mgc")
      mgc workspace set $profile-second > /dev/null
      #Skip "Skipped test to $client"
      When run bash ./spec/retry_command.sh "mgc object-storage objects download --src $test_bucket_name/$file1_name --dst $file1_name-2 --raw"
      #When run mgc object-storage objects download --src $test_bucket_name/$file1_name --dst $file1_name-2 --raw
	    The status should be failure
      #The stderr should include "403"
      The output should include "403"
      ;;
    esac
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
    aws s3api wait bucket-not-exists --bucket $test_bucket_name --profile $profile
  End
End
