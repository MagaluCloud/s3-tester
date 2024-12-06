Include ./spec/known_issues.sh

delete_bucket() {
  profile=$1
  client=$2
  bucket_name="$3"

  aws --profile "$profile" s3api delete-bucket --bucket "$bucket_name" > /dev/null
}

check_length() {
    local str=$1
    if [[ ${#str} -le 2 || ${#str} -eq 64 ]]; then
        return 0  # True
    else
        return 1  # False
    fi
}

Describe 'Create invalid bucket' category:"Skip"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End

  bucket_name="foo bar"
  Describe "with INVALID name with spaces $bucket_name"  id:"002"
    Example "on profile $1 using client $2"
      profile=$1
      client=$2
      Skip if "GL issue #894" skip_known_issues "894" $1 $2

      case "$client" in
      "aws-s3api" | "aws")
        When run aws --profile "$profile" s3api create-bucket --bucket "$bucket_name"
        The error should include 'Invalid bucket name "foo bar"'
        ;;
      "aws-s3")
        When run aws --profile "$profile" s3 mb "s3://$bucket_name"
        The error should include "make_bucket failed: s3://foo bar Parameter validation failed"
        ;;
      "mgc")
        mgc workspace set $profile > /dev/null
        When run bash ./spec/retry_command.sh "mgc object-storage buckets create "$bucket_name" --raw"
        #When run mgc object-storage buckets create "$bucket_name" --raw
        The error should include "InvalidBucketName"
        ;;
      "rclone")
        When run rclone mkdir "$profile:$bucket_name" -v
        The error should include "Failed to mkdir: InvalidBucketName: The specified bucket is not valid."
        ;;
      esac
      The status should be failure
    End
  End
End


Describe 'Create bucket with invalid names' category:"BucketManagement"
  Parameters:matrix
    $PROFILES
    $CLIENTS
    Foobar FOOBAR a ab ebabdabbffceecbacbcbfdccdaaaedfcebbbeffeceeddfadbaccaabdfzqwertq
  End

  Example "on profile $1 using client $2 with invalid name $3"
    profile=$1
    client=$2
    bucket_name=$3

    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api create-bucket --bucket "$bucket_name"
      The error should include 'An error occurred (InvalidBucketName) when calling the CreateBucket operation'
      ;;
    "aws-s3")
      When run aws --profile "$profile" s3 mb "s3://$bucket_name"
      The error should include "make_bucket failed: s3://$bucket_name An error occurred (InvalidBucketName)"
      ;;
    "mgc")
      Skip if "mgc cli está validando tamanho do nome" check_length "$bucket_name"
      When run bash ./spec/retry_command.sh "mgc object-storage buckets create "$bucket_name" --raw"
      # When run mgc object-storage buckets create "$bucket_name" --raw
      The error should include "InvalidBucketName"
      ;;
    "rclone")
      When run rclone mkdir "$profile:$bucket_name" -v
      The error should include "Failed to mkdir"
      ;;
    esac
    The status should be failure
  End
End


%const INVALID_CHARS: "% @ | \\ [ ^ ] { } | &"
Describe 'Create bucket with invalid characters' category:"Skip" id:007
  Parameters:matrix
    $PROFILES
    $CLIENTS
    $INVALID_CHARS
  End

  Example "on profile $1 using client $2 with invalid character $3"
    profile=$1
    client=$2
    char=$3
    bucket_name="test-foo${char}bar"
    Skip if "GL issue #897" skip_known_issues "897" $profile $client $char

    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api create-bucket --bucket "$bucket_name"
      The error should include "Bucket name must match the regex"
      ;;
    "aws-s3")
      When run aws --profile "$profile" s3 mb "s3://$bucket_name"
      The error should include "Bucket name must match the regex"
      ;;
    "mgc")
      Skip if "GL issue #897" skip_known_issues "897" $profile $client $char
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage buckets create "$bucket_name" --raw"
      # When run mgc object-storage buckets create "$bucket_name" --raw
      The  stdout should include "InvalidBucketName"
      ;;
    "rclone")
      When run rclone mkdir "$profile:$bucket_name" -v
      The error should include "InvalidBucketName: The specified bucket is not valid."
      ;;
    esac
    The status should be failure
  End
End
