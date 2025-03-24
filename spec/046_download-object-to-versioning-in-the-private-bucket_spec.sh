Describe 'Download object to versioning in the private bucket:' category:"ObjectVersioning" category:"quick"
  setup(){
    bucket_name="test-046-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"046"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3api create-bucket --bucket $test_bucket_name > /dev/null
    aws s3api --profile $profile put-bucket-acl --bucket $test_bucket_name --grant-write id=$id --grant-read id=$id > /dev/null
    aws s3api --profile $profile put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null
    aws --profile $profile s3 cp $file1_name  s3://$test_bucket_name > /dev/null
    aws --profile $profile s3 cp $file1_name  s3://$test_bucket_name > /dev/null
    aws --profile $profile s3 cp $file1_name  s3://$test_bucket_name > /dev/null
    sleep 10
    version=$(aws s3api list-object-versions --bucket $test_bucket_name --profile $profile | jq -r '.Versions[1].VersionId')
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
   When run bash ./spec/retry_command.sh "aws --profile $profile s3api get-object --bucket $test_bucket_name --key $file1_name --version-id $version $file1_name-2"
    The status should be success
    The output should include "ETag"
      ;;
    "rclone")
    Skip "Skipped test to $client"
      ;;
    "mgc")
    mgc workspace set $profile > /dev/null
    When run bash ./spec/retry_command.sh "mgc object-storage objects download --src $test_bucket_name/$file1_name --obj-version $version --dst ./$file1_name-2 --raw"
    # When run mgc object-storage objects download --src $test_bucket_name/$file1_name --obj-version $version --dst ./$file1_name-2 --raw
    The status should be success
    The output should include "LICENSE"
      ;;
    esac
    aws --profile $profile s3api delete-objects --bucket $test_bucket_name --delete "$(aws --profile $profile s3api list-object-versions --bucket $test_bucket_name| jq '{Objects: [.Versions[] | {Key:.Key, VersionId : .VersionId}], Quiet: false}')"  > /dev/null
    rclone purge --log-file /dev/null "$profile:$test_bucket_name" > /dev/null
    rm -rf $file1_name-2  > /dev/null
  End
End
