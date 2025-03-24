# import functions: # wait_command
Include ./spec/019_utils.sh

Describe 'Access the public bucket and check the list of objects:' category:"BucketPermission" category:"quick"
  setup(){
    bucket_name="test-019-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"019"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3api create-bucket --bucket $test_bucket_name --acl public-read > /dev/null
    # wait_command bucket-exists $profile "$test_bucket_name"
    # wait_command  bucket-exists "$profile-second" "$test_bucket_name"
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null
    aws --profile $profile s3api wait object-exists --bucket $test_bucket_name --key $file1_name
    # wait_command object-exists $profile "$test_bucket_name" "$file1_name"
    # aws wait only checks existence, not access, so there is still more time that can be necessary
    # before a second user can list the contents of a bucket, the time for the access on the
    # acl rule to be propagated, so we are using a # sleep of 5 seconds to give the system some time
    # after the object is there but maybe the permission still not.
    echo "waiting 10 seconds before testing the acl access..."
    # sleep 10
    echo "try listing objects"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run bash ./spec/retry_command.sh "aws --profile $profile-second s3api list-objects-v2 --bucket $test_bucket_name"
      # When run aws --profile $profile-second s3api list-objects-v2 --bucket $test_bucket_name
      The output should include "$file1_name"
      ;;
    "rclone")
      When run bash ./spec/retry_command.sh "rclone ls $profile-second:$test_bucket_name"
      #When run rclone ls $profile-second:$test_bucket_name
      The output should include "$file1_name"
      ;;
    "mgc")
      mgc workspace set $profile-second > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage objects list --dst $test_bucket_name --raw"
      # When run mgc object-storage objects list --dst $test_bucket_name --raw
      The output should include "$file1_name"
      ;;
    esac
    The status should be success
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
    # wait_command bucket-not-exists $profile "$test_bucket_name"
  End
End
