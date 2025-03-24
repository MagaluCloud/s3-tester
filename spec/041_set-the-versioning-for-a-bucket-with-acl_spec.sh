is_variable_null() {
  [ -z "$1" ]
}

Describe 'Set the versioning for a bucket with ACL:' category:"ObjectVersioning" category:"quick"
  setup(){
    bucket_name="test-041-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"041"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    id=$(aws s3api --profile $profile-second list-buckets | jq -r '.Owner.ID')
    #Skip if "No such a "$profile-second" user" is_variable_null "$id"
    if [ "$id" = "" ]; then
      Skip "No such a "$profile-second" user"
      return 0
    fi
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws s3api --profile $profile put-bucket-acl --bucket $test_bucket_name --grant-write id=$id --grant-read id=$id > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run aws s3api --profile $profile put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled
    The output should include ""
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
    mgc workspace set $profile > /dev/null
    When run bash ./spec/retry_command.sh "mgc object-storage buckets versioning enable $test_bucket_name --raw"
    # When run mgc object-storage buckets versioning enable $test_bucket_name --raw
    The output should include "$test_bucket_name"
      ;;
    esac
    The status should be success
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
  End
End
