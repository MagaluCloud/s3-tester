Describe 'Delete bucket with objects with versions:' category:"Skip" category:"quick"
  setup(){
    bucket_name="test-050-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"050"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3api create-bucket --bucket $test_bucket_name > /dev/null
    aws s3api --profile $profile put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null
    aws --profile $profile s3 cp $file1_name  s3://$test_bucket_name > /dev/null
    aws --profile $profile s3 cp $file1_name  s3://$test_bucket_name > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run aws --profile $profile s3 rb s3://$test_bucket_name
    The status should be failure
    The stderr should include BucketNotEmpty
    #aws --profile $profile s3api delete-objects --bucket $test_bucket_name --delete "$(aws --profile $profile s3api list-object-versions --bucket $test_bucket_name| jq '{Objects: [.Versions[] | {Key:.Key, VersionId : .VersionId}], Quiet: false}')" > /dev/null
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
      ;;
    "rclone")
    When run rclone rmdir $profile:$test_bucket_name
    The status should be failure
    The stderr should include BucketNotEmpty
    #aws --profile $profile s3api delete-objects --bucket $test_bucket_name --delete "$(aws --profile $profile s3api list-object-versions --bucket $test_bucket_name| jq '{Objects: [.Versions[] | {Key:.Key, VersionId : .VersionId}], Quiet: false}')" > /dev/null
    #aws --profile $profile s3api delete-objects --bucket $test_bucket_name --delete "$(aws --profile $profile s3api list-object-versions --bucket $test_bucket_name| jq '{Objects: [.DeleteMarkers[] | {Key:.Key, VersionId : .VersionId}], Quiet: false}')" | jq
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
      ;;
    "mgc")
    mgc workspace set $profile > /dev/null
    When run bash ./spec/retry_command.sh "mgc object-storage buckets delete $test_bucket_name --no-confirm --recursive --raw"
    # When run mgc object-storage buckets delete $test_bucket_name --no-confirm --recursive --raw
    The status should be failure
    #The stderr should include "bucket contains multiple versions of objects"
    The stdout should include "bucket contains multiple versions of objects"
    #aws --profile $profile s3api delete-objects --bucket $test_bucket_name --delete "$(aws --profile $profile s3api list-object-versions --bucket $test_bucket_name| jq '{Objects: [.Versions[] | {Key:.Key, VersionId : .VersionId}], Quiet: false}')" > /dev/null
    #aws --profile $profile s3api delete-objects --bucket $test_bucket_name --delete "$(aws --profile $profile s3api list-object-versions --bucket $test_bucket_name| jq '{Objects: [.DeleteMarkers[] | {Key:.Key, VersionId : .VersionId}], Quiet: false}')" > /dev/null
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
      ;;
    esac
  End
End
