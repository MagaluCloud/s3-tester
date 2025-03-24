Describe 'Copy URL for public buckets:' category:"BucketPermission" category:"quick"
  setup(){
    bucket_name="test-033-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"033"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    case "$client" in
    "aws" | "aws-s3")
    Skip "Skipped test to $client"
      ;;
    "aws-s3api")
    Skip "Skipped test to $client"
      ;;
    "rclone")
    Skip "Skipped test to $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage buckets public-url --dst $test_bucket_name --raw"
      # When run mgc object-storage buckets public-url --dst $test_bucket_name --raw
      The output should include "$test_bucket_name"
      ;;
    esac
    The status should be success
  End
End
