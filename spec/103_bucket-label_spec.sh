Include ./spec/019_utils.sh
is_variable_null() {
  [ -z "$1" ]
}

Describe 'Set bucket label:' category:"BucketLabelling" category:"slow"
  setup(){
    bucket_name="test-103-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"103"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    label='marketing'
    mgc workspace set $profile > /dev/null
    mgc object-storage buckets create $test_bucket_name > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      Skip "Skipped test to $client"
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
      When run mgc object-storage buckets label set --bucket $test_bucket_name --label $label
      The stdout should include ""
      The status should be success
      ;;
    esac
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

Describe 'Get bucket label:' category:"BucketLabelling" category:"slow"
  setup(){
    bucket_name="test-103-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"103"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    label='marketing'
    mgc workspace set $profile > /dev/null
    mgc object-storage buckets create $test_bucket_name > /dev/null
    mgc object-storage buckets label set --bucket $test_bucket_name --label $label > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      Skip "Skipped test to $client"
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
      When run mgc object-storage buckets label get --bucket $test_bucket_name
      The stdout should include "marketing"
      The status should be success
      ;;
    esac
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

Describe 'Delete bucket label:' category:"BucketLabelling"
  setup(){
    bucket_name="test-103-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"103"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    label_delete='to-delete'
    labels="marketing,${label_delete}"
    mgc workspace set $profile > /dev/null
    mgc object-storage buckets create $test_bucket_name > /dev/null
    mgc object-storage buckets label set --bucket $test_bucket_name --label $labels > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      Skip "Skipped test to $client"
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
      mgc object-storage buckets label delete --bucket $test_bucket_name --label $label_delete
      When run mgc object-storage buckets label get --bucket $test_bucket_name
      The stdout should include "marketing"
      The stdout should not include $label_delete
      The status should be success
      ;;
    esac
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End
