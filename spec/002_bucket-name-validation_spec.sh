Include ./spec/known_issues.sh

# import functions: wait_command
Include ./spec/019_utils.sh


delete_bucket() {
  profile=$1
  client=$2
  bucket_name="$3"

  aws --profile "$profile" s3api delete-bucket --bucket "$bucket_name" > /dev/null
  wait_command bucket-not-exists "$profile" "$bucket_name"
}

check_length() {
    local str=$1
    if [[ ${#str} -le 2 || ${#str} -eq 64 ]]; then
        return 0  # True
    else
        return 1  # False
    fi
}

Describe 'Create bucket' category:"BucketManagement" category:"quick"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End

  bucket_name="testeee$(openssl rand -hex 40 | tr -dc '[:lower:]' | head -c 40)"
  Describe "with VALID name with only lowercase letters $bucket_name"  id:005
    Example "on profile $1 using client $2"
      profile=$1
      client=$2

      case "$client" in
      "aws-s3api" | "aws")
        When run aws --profile "$profile" s3api create-bucket --bucket "$bucket_name"
        The output should include "\"Location\": \"/$bucket_name\""
        ;;
      "aws-s3")
        When run aws --profile "$profile" s3 mb "s3://$bucket_name"
        The output should include "make_bucket: $bucket_name"
        ;;
      "mgc")
        mgc workspace set $profile > /dev/null
        When run bash ./spec/retry_command.sh "mgc object-storage buckets create "$bucket_name" --raw"
        #When run mgc object-storage buckets create "$bucket_name" --raw
        The output should include "$bucket_name"
        ;;
      "rclone")
        When run rclone mkdir "$profile:$bucket_name" -v
        The error should include "Bucket \"$bucket_name\" created"
        ;;
      esac
      The status should be success
      wait_command bucket-exists "$profile" "$bucket_name"
      Assert delete_bucket "$1" "$2" "$bucket_name"
    End
  End

  bucket_name="212121$(openssl rand -hex 40 | tr -dc '0-9' | head -c 40)"
  Describe "with VALID name with only numbers $bucket_name"  id:006 
    Example "on profile $1 using client $2"
      profile=$1
      client=$2

      case "$client" in
      "aws-s3api" | "aws")
        When run aws --profile "$profile" s3api create-bucket --bucket "$bucket_name"
        The output should include "\"Location\": \"/$bucket_name\""
        ;;
      "aws-s3")
        When run aws --profile "$profile" s3 mb "s3://$bucket_name"
        The output should include "make_bucket: $bucket_name"
        ;;
      "mgc")
        mgc workspace set $profile > /dev/null
        When run bash ./spec/retry_command.sh "mgc object-storage buckets create "$bucket_name" --raw"
        #When run mgc object-storage buckets create "$bucket_name" --raw
        The output should include "$bucket_name"
        ;;
      "rclone")
        When run rclone mkdir "$profile:$bucket_name" -v
        The error should include "Bucket \"$bucket_name\" created"
        ;;
      esac
      The status should be success
      wait_command bucket-exists "$profile" "$bucket_name"
      Assert delete_bucket "$1" "$2" "$bucket_name"
      wait_command bucket-not-exists "$profile" "$bucket_name"
    End
  End

  PREFIX="s3-tester-$(openssl rand -hex 10 | tr -dc 'a-z0-9' | head -c 10)"
  bucket_name="$PREFIX-foo"
  Describe "with VALID name $bucket_name" id:008
    Example "on profile $1 using client $2"
      profile=$1
      client=$2

      case "$client" in
      "aws-s3api" | "aws")
        When run aws --profile "$profile" s3api create-bucket --bucket "$bucket_name"
        The output should include "\"Location\": \"/$bucket_name\""
        ;;
      "aws-s3")
        When run aws --profile "$profile" s3 mb "s3://$bucket_name"
        The output should include "make_bucket: $bucket_name"
        ;;
      "mgc")
        mgc workspace set $profile > /dev/null
        When run bash ./spec/retry_command.sh "mgc object-storage buckets create "$bucket_name" --raw"
        #When run mgc object-storage buckets create "$bucket_name" --raw
        The output should include "$bucket_name"
        ;;
      "rclone")
        When run rclone mkdir "$profile:$bucket_name" -v
        The error should include "$bucket_name"
        ;;
      esac
      The status should be success
      wait_command bucket-exists "$profile" "$bucket_name"
      Assert delete_bucket "$1" "$2" "$bucket_name"
    End
  End
End
