# import functions: wait_command
Include ./spec/019_utils.sh
is_variable_null() {
  [ -z "$1" ]
}

Describe 'Put bucket tagging:' category:"BucketLabelling" category:"quick"
  setup(){
    bucket_name="test-092-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"092"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    tag='TagSet=[{Key=organization,Value=marketing}]'
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null 
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-tagging --bucket $test_bucket_name --tagging $tag
      The stdout should include ""
      The status should be success
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
      Skip "Skipped test to $client"
      ;;
    esac
    #wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Get bucket tagging:' category:"BucketTagging" category:"quick"
  setup(){
    bucket_name="test-092-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"092"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    tag='TagSet=[{Key=organization,Value=marketing}]'
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null 
    aws --profile $profile s3api put-bucket-tagging --bucket $test_bucket_name --tagging $tag
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api get-bucket-tagging --bucket $test_bucket_name
      The stdout should include "organization"
      The status should be success
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
      Skip "Skipped test to $client"
      ;;
    esac
    #wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Delete bucket tagging:' category:"BucketTagging" category:"quick"
  setup(){
    bucket_name="test-092-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"092"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    tag='TagSet=[{Key=organization,Value=marketing}]'
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null 
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api delete-bucket-tagging --bucket $test_bucket_name
      The stdout should include ""
      The status should be success
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
      Skip "Skipped test to $client"
      ;;
    esac
    #wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Put bucket tagging wrong json:' category:"BucketTagging" category:"quick"
  setup(){
    bucket_name="test-092-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"092"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    tag='TagSet=[{Key=organization,Value=marketing]'
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null 
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-tagging --bucket $test_bucket_name --tagging $tag
      The stderr should include "Error parsing parameter '--tagging'"
      The status should be failure
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
      Skip "Skipped test to $client"
      ;;
    esac
    #wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Put bucket tagging with wrong "value":' category:"BucketTagging" category:"quick"
  setup(){
    bucket_name="test-092-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"092"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    tag='TagSet=[{key=organization,value=marketing}]'
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null 
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-tagging --bucket $test_bucket_name --tagging $tag
      The stderr should include "Missing required parameter in Tagging.TagSet[0]:"
      The status should be failure
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
      Skip "Skipped test to $client"
      ;;
    esac
    #wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Put bucket tagging with file:' category:"BucketTagging" category:"quick"
  setup(){
    bucket_name="test-092-$(date +%s)"
    file1_name="tagging.json"
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"092"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null 
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-tagging --bucket $test_bucket_name --tagging file://$file1_name
      The stderr should include ""
      The status should be success
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
      Skip "Skipped test to $client"
      ;;
    esac
    #wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Put bucket tagging with wrong file:' category:"BucketTagging" category:"quick"
  setup(){
    bucket_name="test-092-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"092"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null 
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-tagging --bucket $test_bucket_name --tagging file://$file1_name
      The stderr should include ""
      The status should be failure
      ;;
    "rclone")
      Skip "Skipped test to $client"
      ;;
    "mgc")
      Skip "Skipped test to $client"
      ;;
    esac
    #wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End
