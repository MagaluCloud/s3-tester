Include ./spec/019_utils.sh
delete_bucket() {
  profile=$1
  client=$2
  bucket_name="$3"

  rclone purge --log-file /dev/null "$profile:$bucket_name" > /dev/null
  wait_command bucket-not-exists $profile "$bucket_name" "$file1_name"
}

Describe 'List buckets' category:"BucketManagement" id:"011" category:"quick"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End

  PREFIX="s3-tester-$(openssl rand -hex 10 | tr -dc 'a-z0-9' | head -c 10)"
  bucket_name="$PREFIX-foo"

  Example "on profile $1 using client $2"
    profile=$1
    client=$2

    # Create sample bucket to validate listing
    aws --profile "$profile" s3api create-bucket --bucket "$bucket_name"> /dev/null
    wait_command bucket-exists $profile "$bucket_name" "$file1_name"

    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api list-buckets
      The output should include "\"Name\": \"$bucket_name\""
      ;;
    "aws-s3")
      When run aws --profile "$profile" s3 ls "s3://"
      The output should include "$bucket_name"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage buckets list --raw"
      #When run mgc object-storage buckets list --raw
      The output should include "$bucket_name"
      ;;
    "rclone")
      When run rclone lsd "$profile:"
      The output should include "$bucket_name"
      ;;
    esac
    The status should be success
    Assert delete_bucket "$1" "$2" "$bucket_name"
  End
End


Describe 'Delete buckets' category:"BucketManagement"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End

  PREFIX="s3-tester-$(openssl rand -hex 10 | tr -dc 'a-z0-9' | head -c 10)"
  bucket_name="$PREFIX-foo"
  Example "delete empty bucket $bucket_name on profile $1 using client $2" id:"015"
    profile=$1
    client=$2

    # Create sample bucket to validate deleting
    aws --profile "$profile" s3api create-bucket --bucket "$bucket_name" > /dev/null
    wait_command bucket-exists $profile "$bucket_name" "$file1_name"

    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api delete-bucket --bucket "$bucket_name"
      The output should equal ""
      ;;
    "aws-s3")
      When run aws --profile "$profile" s3 rb "s3://$bucket_name"
      The output should equal "remove_bucket: $bucket_name"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage buckets delete "$bucket_name" --no-confirm --raw"
      #When run mgc object-storage buckets delete "$bucket_name" --no-confirm --raw
      The output should equal ""
      ;;
    "rclone")
      When run rclone rmdir "$profile:$bucket_name" -v
      The error should include "Bucket \"$bucket_name\" deleted"
      ;;
    esac
    The status should be success
    aws --profile "$profile" s3api wait bucket-not-exists --bucket "$bucket_name"
  End

  Example "delete bucket with data $bucket_name on profile $1 using client $2" id:"016"
    profile=$1
    client=$2

    # Create sample bucket to validate deleting
    aws --profile "$profile" s3api create-bucket --bucket "$bucket_name" > /dev/null
    wait_command bucket-exists $profile "$bucket_name"
    aws --profile "$profile" s3api put-object --bucket "$bucket_name" --key foo --body README.md> /dev/null
    wait_command object-exists $profile "$bucket_name" "foo"

    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api delete-bucket --bucket "$bucket_name"
      The error should include "BucketNotEmpty"
      The status should be failure
      Assert delete_bucket "$1" "$2" "$bucket_name"
      ;;
    "aws-s3" | "aws-s3api" | "aws")
      When run aws --profile "$profile" s3 rb "s3://$bucket_name" --force
      The output should include "remove_bucket: $bucket_name"
      The status should be success
      aws --profile "$profile" s3api wait bucket-not-exists --bucket "$bucket_name"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage buckets delete "$bucket_name" --recursive --no-confirm --raw"
      #When run mgc object-storage buckets delete "$bucket_name" --recursive --no-confirm --raw
      The status should be success
      The output should be blank
      aws --profile "$profile" s3api wait bucket-not-exists --bucket "$bucket_name"
      ;;
    "rclone")
      When run rclone purge "$profile:$bucket_name" -v
      The error should include "Bucket \"$bucket_name\" deleted"
      The status should be success
      aws --profile "$profile" s3api wait bucket-not-exists --bucket "$bucket_name"
      ;;
    esac
  End
End


