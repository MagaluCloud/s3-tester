Describe 'Upload object to versioning in the public bucket:' category:"ObjectVersioning" category:"quick"
  setup(){
    bucket_name="test-042-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"042"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3api create-bucket --bucket $test_bucket_name --acl public-read  > /dev/null
    aws s3api --profile $profile put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    When run aws --profile $profile s3 cp $file1_name s3://$test_bucket_name
    The status should be success
    The output should include "$file1_name"
      ;;
    "rclone")
    When run rclone copy $file1_name $profile:$test_bucket_name
    The status should be success
    The output should include ""
      ;;
    "mgc")
    mgc workspace set $profile > /dev/null
    When run bash ./spec/retry_command.sh "mgc object-storage objects upload --src $file1_name --dst $test_bucket_name --raw"
    # When run mgc object-storage objects upload --src $file1_name --dst $test_bucket_name --raw
    The status should be success
    The output should include ""
      ;;
    esac
    #aws --profile $profile s3api delete-objects --bucket $test_bucket_name --delete "$(aws --profile $profile s3api list-object-versions --bucket $test_bucket_name| jq '{Objects: [.Versions[] | {Key:.Key, VersionId : .VersionId}], Quiet: false}')"  > /dev/null
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
  End
End
