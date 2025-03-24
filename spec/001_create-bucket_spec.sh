# constants
% UNIQUE_SUFIX: $(date +%s)

get_test_bucket_name(){
  echo "test-001-$profile-$client-$UNIQUE_SUFIX"
}
#001 is also used as setup for 015
Describe 'Create bucket' category:"BucketManagement" id:"001" id:"015" category:"quick"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "with unique name on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api create-bucket --bucket "$bucket_name"
      The status should be success
      The output should include "\"Location\": \"/$bucket_name\""
      ;;
    "aws-s3")
      When run aws --profile "$profile" s3 mb "s3://$bucket_name"
      The status should be success
      The output should include "make_bucket: $bucket_name"
      ;;
    "rclone")
      When run rclone mkdir "$profile:$bucket_name" -v
      The status should be success
      The error should include "Bucket \"$bucket_name\" created"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage buckets create "$bucket_name" --raw" 
      #When run mgc object-storage buckets create "$bucket_name" --raw
      The status should be success
      The output should include "$bucket_name"
      ;;
    esac
    #aws --profile "$profile" s3api wait bucket-exists --bucket "$bucket_name"
  End
End

#015 is also used as teardown of 001
Describe 'Delete Buckets empty' category:"BucketManagement" id:"001" id:"015" category:"quick"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "for profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api delete-bucket --bucket "$bucket_name"
      The status should be success
      ;;
    "aws-s3")
      When run aws --profile "$profile" s3 rb "s3://$bucket_name"
      The status should be success
      The output should include "remove_bucket: $bucket_name"
      ;;
    "rclone")
      When run rclone rmdir "$profile:$bucket_name" -v
      The status should be success
      The error should include "S3 bucket $bucket_name: Bucket \"$bucket_name\" deleted"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage buckets delete "$bucket_name" --no-confirm --raw"
      #When run mgc object-storage buckets delete "$bucket_name" --no-confirm --raw
      The status should be success
      The output should include ""
      ;;
    esac
    #aws --profile "$profile" s3api wait bucket-not-exists --bucket "$bucket_name"
  End
End
