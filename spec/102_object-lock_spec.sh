# import functions: wait_command
Include ./spec/019_utils.sh

setup_lock(){
    local bucket_name=$1
    local client=$2
    local profile=$3
    local test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3api create-bucket --bucket $test_bucket_name --object-lock-enabled-for-bucket > /dev/null
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null
}

Describe 'Put bucket default lock:' category:"ObjectLocking" category:"quick"
  setup(){
    bucket_name="test-102-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2:" id:"102"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    setup_lock $bucket_name $client $profile
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-object-lock-configuration --bucket $test_bucket_name --object-lock-configuration '{"ObjectLockEnabled": "Enabled", "Rule":{"DefaultRetention":{"Mode":"COMPLIANCE","Days":1}}}'
      The stdout should include ""
      The status should be success
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "No such operation in client $client"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Put bucket default lock in old bucket:' category:"ObjectLocking" category:"quick"
  setup(){
    bucket_name="test-102-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2:" id:"102"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3api create-bucket --bucket $test_bucket_name > /dev/null
    aws --profile $profile s3api put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-object-lock-configuration --bucket $test_bucket_name --object-lock-configuration '{"ObjectLockEnabled": "Enabled", "Rule":{"DefaultRetention":{"Mode":"COMPLIANCE","Days":1}}}'
      The stdout should include ""
      The status should be success
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "No such operation in client $client"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

## this test dont permit delete bucket until 1 day after
# Describe 'Put object in bucket with default lock and validate:' category:"ObjectLocking"
#   setup(){
#     bucket_name="test-102-$(date +%s)"
#     file1_name="LICENSE"
#   }
#   Before 'setup'
#   Parameters:matrix
#     $PROFILES
#     $CLIENTS
#   End
#   Example "on profile $1 using client $2:" id:"102"
#     profile=$1
#     client=$2
#     test_bucket_name="$bucket_name-$client-$profile"
#     setup_lock $bucket_name $client $profile
#     date_plus_day=$(date -u -d "1 day" +"%Y-%m-%dT%H:%M:%SZ")
#     case "$client" in
#     "aws-s3api" | "aws" | "aws-s3")
#       aws --profile $profile s3api put-object-lock-configuration --bucket $test_bucket_name --object-lock-configuration "{\"ObjectLockEnabled\": \"Enabled\", \"Rule\":{\"DefaultRetention\":{\"Mode\":\"COMPLIANCE\",\"Days\":1}}}" > /dev/null
#       aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null
#       When run aws --profile $profile s3api get-object-retention --bucket $test_bucket_name --key $file1_name
#       new_date=$(date -u -d "$date_plus_day" +"%Y-%m-%dT%H:%M")
#       The stdout should include $new_date
#       The status should be success
#       ;;
#     "rclone")
#       Skip "No such operation in client $client"
#       ;;
#     "mgc")
#       Skip "No such operation in client $client"
#       ;;
#     esac
#   End
# End

Describe 'Put object in bucket without default lock and validate date:' category:"ObjectLocking" category:"quick"
  setup(){
    bucket_name="test-102-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2:" id:"102"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    setup_lock $bucket_name $client $profile
    date_plus_minute=$(date -u -d "1 minute" +"%Y-%m-%dT%H:%M:%SZ")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      aws --profile $profile s3api put-object-retention --bucket $test_bucket_name --key $file1_name --retention "{\"Mode\":\"COMPLIANCE\",\"RetainUntilDate\":\"$date_plus_minute\"}"
      When run aws --profile $profile s3api get-object-retention --bucket $test_bucket_name --key $file1_name
      new_date=$(date -u -d "$date_plus_minute" +"%Y-%m-%dT%H:%M")
      The stdout should include $new_date
      The status should be success
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "No such operation in client $client"
      ;;
    esac
    sleep 60
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Try delete locked object:' category:"ObjectLocking" category:"quick"
  setup(){
    bucket_name="test-102-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2:" id:"102"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    setup_lock $bucket_name $client $profile
    date_plus_minute=$(date -u -d "1 minute" +"%Y-%m-%dT%H:%M:%SZ")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3 rm s3://$test_bucket_name/$file1_name
      The stdout should include "delete: s3://$test_bucket_name/$file1_name"
      The status should be success
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "No such operation in client $client"
      ;;
    esac
    sleep 60
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Remove object lock and try delete especified version old locked:' category:"ObjectLocking" category:"quick"
  setup(){
    bucket_name="test-102-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2:" id:"102"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    setup_lock $bucket_name $client $profile
    date_plus_minute=$(date -u -d "2 minute" +"%Y-%m-%dT%H:%M:%SZ")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      aws --profile $profile s3api put-object-lock-configuration --bucket $test_bucket_name --object-lock-configuration "{\"ObjectLockEnabled\": \"Enabled\", \"Rule\":{\"DefaultRetention\":{\"Mode\":\"COMPLIANCE\",\"Days\":1}}}" > /dev/null
      sleep 5
      aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null
      aws --profile $profile s3api put-object-lock-configuration --bucket $test_bucket_name --object-lock-configuration  "{\"ObjectLockEnabled\": \"Enabled\"}" > /dev/null
      aws --profile $profile s3 rm s3://$test_bucket_name/$file1_name > /dev/null
      When run aws --profile $profile s3 rb s3://$test_bucket_name/ --force
      The stderr should include "(BucketNotEmpty)"
      The status should be failure
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "No such operation in client $client"
      ;;
    esac
    #sleep 120
    wait_command bucket-exists "$profile" "$test_bucket_name"
    #rclone purge $profile:$test_bucket_name > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'InvalidRequest Object locking not enabled:' category:"ObjectLocking" category:"quick"
  setup(){
    bucket_name="test-102-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2:" id:"102"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api get-object-retention --bucket $test_bucket_name --key $file1_name
      The stderr should include "An error occurred (InvalidRequest) when calling the GetObjectRetention operation: Bucket is missing Object Lock Configuration"
      The status should be failure
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "No such operation in client $client"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Remove default bucket lock:' category:"ObjectLocking" category:"quick"
  setup(){
    bucket_name="test-102-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2:" id:"102"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    setup_lock $bucket_name $client $profile
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      aws --profile $profile s3api put-object-lock-configuration --bucket $test_bucket_name --object-lock-configuration "{\"ObjectLockEnabled\": \"Enabled\", \"Rule\":{\"DefaultRetention\":{\"Mode\":\"COMPLIANCE\",\"Days\":1}}}"
      When run aws --profile $profile s3api put-object-lock-configuration --bucket $test_bucket_name --object-lock-configuration "{\"ObjectLockEnabled\": \"Enabled\"}"
      The stdout should include ""
      The status should be success
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "No such operation in client $client"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Try enable object lock on not versioned bucket:' category:"ObjectLocking" category:"quick"
  setup(){
    bucket_name="test-102-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2:" id:"102"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3api create-bucket --bucket $test_bucket_name > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-object-lock-configuration --bucket $test_bucket_name --object-lock-configuration '{"ObjectLockEnabled": "Enabled", "Rule":{"DefaultRetention":{"Mode":"COMPLIANCE","Days":1}}}'
      The stderr should include "An error occurred (InvalidBucketState) when calling the PutObjectLockConfiguration operation: Versioning must be 'Enabled' on the bucket to apply a Object Lock configuration"
      The status should be failure
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "No such operation in client $client"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Put retention with past date:' category:"ObjectLocking" category:"quick"
  setup(){
    bucket_name="test-102-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2:" id:"102"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    setup_lock $bucket_name $client $profile
    date_decrease_minute=$(date -u -d "10 minutes ago" +"%Y-%m-%dT%H:%M:%SZ")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-object-retention --bucket $test_bucket_name --key $file1_name --retention "{\"Mode\":\"COMPLIANCE\",\"RetainUntilDate\":\"$date_decrease_minute\"}"
      The stderr should include "An error occurred (InvalidArgument) when calling the PutObjectRetention operation: The retain until date must be in the future!"
      The status should be failure
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "No such operation in client $client"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Decrease date on retention:' category:"ObjectLocking" category:"quick"
  setup(){
    bucket_name="test-102-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2:" id:"102"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    setup_lock $bucket_name $client $profile
    date_plus_minute=$(date -u -d "1 minute" +"%Y-%m-%dT%H:%M:%SZ")
    date_plus_2minutes=$(date -u -d "2 minute" +"%Y-%m-%dT%H:%M:%SZ")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      aws --profile $profile s3api put-object-retention --bucket $test_bucket_name --key $file1_name --retention "{\"Mode\":\"COMPLIANCE\",\"RetainUntilDate\":\"$date_plus_2minutes\"}"
      When run aws --profile $profile s3api put-object-retention --bucket $test_bucket_name --key $file1_name --retention "{\"Mode\":\"COMPLIANCE\",\"RetainUntilDate\":\"$date_plus_minute\"}"
      The stderr should include "An error occurred (AccessDenied) when calling the PutObjectRetention operation: Access Denied because object protected by object lock."
      The status should be failure
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "No such operation in client $client"
      ;;
    esac
    sleep 120
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Try disable:' category:"ObjectLocking" category:"quick"
  setup(){
    bucket_name="test-102-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2:" id:"102"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    setup_lock $bucket_name $client $profile
    date_plus_minute=$(date -u -d "1 minute" +"%Y-%m-%dT%H:%M:%SZ")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-object-lock-configuration --bucket $test_bucket_name --object-lock-configuration '{"ObjectLockEnabled": "Disabled"}'
      The stderr should include "An error occurred (MalformedXML) when calling the PutObjectLockConfiguration operation: The XML you provided was not well-formed or did not validate against our published schema"
      The status should be failure
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "No such operation in client $client"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Try put with wrong Mode:' category:"ObjectLocking" category:"quick"
  setup(){
    bucket_name="test-102-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2:" id:"102"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    setup_lock $bucket_name $client $profile
    date_plus_minute=$(date -u -d "1 minute" +"%Y-%m-%dT%H:%M:%SZ")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-object-retention --bucket $test_bucket_name --key $file1_name --retention "{\"Mode\":\"WRONG\",\"RetainUntilDate\":\"$date_plus_minute\"}"
      The stderr should include "An error occurred (MalformedXML) when calling the PutObjectRetention operation: The XML you provided was not well-formed or did not validate against our published schema"
      The status should be failure
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "No such operation in client $client"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Bucket without default lock, and get object retention:' category:"ObjectLocking" category:"quick"
  setup(){
    bucket_name="test-102-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2:" id:"102"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    setup_lock $bucket_name $client $profile
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api get-object-retention --bucket $test_bucket_name --key $file1_name
      The stderr should include "An error occurred (NoSuchObjectLockConfiguration) when calling the GetObjectRetention operation: The specified object does not have a ObjectLock configuration"
      The status should be failure
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "No such operation in client $client"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    rclone purge $profile:$test_bucket_name > /dev/null
    wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End
