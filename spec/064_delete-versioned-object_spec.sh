# 064: Delete versioned object

#constants
% UNIQUE_SUFIX: $(date +%s)
# aws s3 dont have versioning commands so we filter out of test 65
% FILTERED_CLIENTS:$(echo "$CLIENTS" | tr ' ' '\n' | grep -v '^aws-s3$' | tr '\n' ' ')

# imported functions:
#   create_bucket, enable_versioning, put_object
#   create_bucket_success_output, enable_versioning_success_output, put_object_success_output
Include ./spec/064_utils.sh

get_test_bucket_name(){
  echo "test-$profile-$client-$UNIQUE_SUFIX"
}
get_uploaded_key(){
  echo "test--$profile--$client--$1--$UNIQUE_SUFIX"
}
Describe "setup 064" category:"Skip" id:"064" category:"slow"
  Parameters:matrix
    $PROFILES
    $FILTERED_CLIENTS
  End
  Example "create test bucket for profile $1 using $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    When run create_bucket $profile $client $bucket_name
    The status should be success
    The output should include "$(create_bucket_success_output $profile $client $bucket_name)"
  End
  Example "enable versioning on test bucket of profile $1 using $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    When run enable_versioning $profile $client $bucket_name
    The status should be success
    The output should include "$(enable_versioning_success_output $profile $client $bucket_name)"
  End
  Example "upload object on versioning-enabled bucket of profile $1 using $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    local_file="LICENSE"
    key=$(get_uploaded_key "$local_file")
    When run put_object $profile $client $bucket_name $local_file $key
    The status should be success
    The output should include "$(put_object_success_output $profile $client $bucket_name $local_file $key)"
  End
  Example "overwrite object on versioning-enabled bucket of profile $1 using $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    key=$(get_uploaded_key "LICENSE")
    other_local_file="README.md"
    When run put_object $profile $client $bucket_name $other_local_file $key
    The status should be success
    The output should include "$(put_object_success_output $profile $client $bucket_name $local_file $key)"
  End
  Example "list versions of test bucket on profile $1 using $2 should have versions"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    key=$(get_uploaded_key "LICENSE")
    When run list_object_versions $profile $client $bucket_name
    The status should be success
    The output should include "$(list_object_versions_success_output $profile $client $bucket_name $key)"
  End
End

Describe "Delete versioned object" category:"Skip" id:"064"
  Parameters:matrix
    $PROFILES
    $FILTERED_CLIENTS
  End
  Example "delete object on versioning-enabled bucket of profile $1 using $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    local_file="LICENSE"
    key=$(get_uploaded_key "$local_file")
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile $profile s3api delete-object --bucket $bucket_name --key $key --debug
      The status should be success
      The error should include "DELETE /$bucket_name/$key HTTP/1.1\" 204 0"
      ;;
    "rclone")
      When run rclone deletefile "$profile:$bucket_name/$key" -v
      The status should be success
      The error should include "$key: Deleted"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc --debug object-storage objects delete --dst="$bucket_name/$key" --no-confirm --raw"
      # When run mgc --debug object-storage objects delete --dst="$bucket_name/$key" --no-confirm --raw
      The status should be success
      The stdout should include "$bucket_name?delete="
      The stdout should include "<Deleted><Key>$key</Key></Deleted>"
      ;;
    esac
  End
  Example "list versions of profile $1 test bucket using $2 should list versions of the deleted key"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    local_file="LICENSE"
    key=$(get_uploaded_key "$local_file")
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile $profile s3api list-object-versions --bucket $bucket_name --query DeleteMarkers
      The status should be success
      The output should include "\"Key\": \"$key\","
      ;;
    "rclone")
      rclone ls $profile:$bucket_name
      When run rclone --s3-versions ls $profile:$bucket_name
      The status should be success
      The line 1 of output should include "$key-v"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage objects versions --dst="$bucket_name" --output json --raw"
      # When run mgc object-storage objects versions --dst="$bucket_name" --cli.output json --raw
      The status should be success
      The output should not include "\"isLatest\": true,"
      ;;
    esac
  End
End

Describe "teardown 064" category:"Skip" id:"064"
  Parameters:matrix
    $PROFILES
    $FILTERED_CLIENTS
  End
  # delete test bucket, if created
  Example "delete test bucket for profile $1 client $2 using rclone purge"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    When run rclone purge --s3-versions "$profile:$bucket_name"
    The status should be success
  End
End
