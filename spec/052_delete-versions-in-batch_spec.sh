Describe 'Delete versions in batch:' category:"ObjectVersioning" category:"quick"
  setup(){
    bucket_name="test-052-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"052"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile" 
    aws --profile $profile s3api create-bucket --bucket $test_bucket_name > /dev/null
    aws s3api --profile $profile put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null
    aws --profile $profile s3 cp $file1_name  s3://$test_bucket_name > /dev/null
    aws --profile $profile s3 cp $file1_name  s3://$test_bucket_name > /dev/null
    sleep 10
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run aws --profile $profile s3api delete-objects --bucket $test_bucket_name --delete "$(aws --profile $profile s3api list-object-versions --bucket $test_bucket_name| jq '{Objects: [.Versions[] | {Key:.Key, VersionId : .VersionId}], Quiet: false}')"
    The status should be success
    The output should include "Deleted"
      ;;
    "rclone")
    aws --profile $profile s3api delete-objects --bucket $test_bucket_name --delete "$(aws --profile $profile s3api list-object-versions --bucket $test_bucket_name| jq '{Objects: [.Versions[] | {Key:.Key, VersionId : .VersionId}], Quiet: false}')" > /dev/null
    Skip "Skipped test to $client"
      ;;
    "mgc")
    aws --profile $profile s3api delete-objects --bucket $test_bucket_name --delete "$(aws --profile $profile s3api list-object-versions --bucket $test_bucket_name| jq '{Objects: [.Versions[] | {Key:.Key, VersionId : .VersionId}], Quiet: false}')" > /dev/null
    Skip "Skipped test to $client"
      ;;
    esac
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
  End
End
