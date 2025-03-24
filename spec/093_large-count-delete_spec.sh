Include ./spec/019_utils.sh

Describe 'Delete large bucket with 100 objects:' category:"BigBuckets"
  setup(){
    bucket_name="test-093-$(date +%s)"
    files_count=100
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"093"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    for i in $(seq 1 $files_count); do
      touch ./report/arquivo_$i.txt
    done
    aws --profile $profile s3 sync ./report/ s3://$test_bucket_name > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      start_time=$(date +%s) > /dev/null
      When run bash ./spec/retry_command.sh "aws --profile $profile s3 rb s3://$test_bucket_name --force" 5000
      # When run aws --profile $profile s3 rb s3://$test_bucket_name --force
      end_time=$(date +%s) > /dev/null
      remove_bucket_time=$((end_time - start_time)) > /dev/null
      echo "Time to remove bucket with $files_count files on profile $profile: $remove_bucket_time seconds" >> ./report/benchmark-delete.tap
      The stdout should include ""
      #The stderr should include ""
      The status should be success
      ;;
    "rclone")
      start_time=$(date +%s) > /dev/null
      When run rclone purge $profile:$test_bucket_name
      end_time=$(date +%s) > /dev/null
      remove_bucket_time=$((end_time - start_time)) > /dev/null
      echo "Time to remove bucket with $files_count files on profile $profile: $remove_bucket_time seconds" >> ./report/benchmark-delete.txt
      The stdout should include ""
      The status should be success
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      start_time=$(date +%s) > /dev/null
      When run mgc object-storage buckets delete --recursive --bucket $test_bucket_name
      end_time=$(date +%s) > /dev/null
      remove_bucket_time=$((end_time - start_time)) > /dev/null
      echo "Time to remove bucket with $files_count files on profile $profile: $remove_bucket_time seconds" >> ./report/benchmark-delete.txt
      The stdout should include ""
      The status should be success
      ;;
    esac
  End
End

Describe 'Delete large bucket with 1000 objects:' category:"BigBuckets"
  setup(){
    bucket_name="test-093-$(date +%s)"
    files_count=1000
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"093"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    for i in $(seq 1 $files_count); do
      touch ./report/arquivo_$i.txt
    done
    aws --profile $profile s3 sync ./report/ s3://$test_bucket_name > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      start_time=$(date +%s) > /dev/null
      When run bash ./spec/retry_command.sh "aws --profile $profile s3 rb s3://$test_bucket_name --force" 5000
      # When run aws --profile $profile s3 rb s3://$test_bucket_name --force
      end_time=$(date +%s) > /dev/null
      remove_bucket_time=$((end_time - start_time)) > /dev/null
      echo "Time to remove bucket with $files_count files on profile $profile: $remove_bucket_time seconds" >> ./report/benchmark-delete.tap
      The stdout should include ""
      #The stderr should include ""
      The status should be success
      ;;
    "rclone")
      start_time=$(date +%s) > /dev/null
      When run rclone purge $profile:$test_bucket_name
      end_time=$(date +%s) > /dev/null
      remove_bucket_time=$((end_time - start_time)) > /dev/null
      echo "Time to remove bucket with $files_count files on profile $profile: $remove_bucket_time seconds" >> ./report/benchmark-delete.txt
      The stdout should include ""
      The status should be success
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      start_time=$(date +%s) > /dev/null
      When run mgc object-storage buckets delete --recursive --bucket $test_bucket_name
      end_time=$(date +%s) > /dev/null
      remove_bucket_time=$((end_time - start_time)) > /dev/null
      echo "Time to remove bucket with $files_count files on profile $profile: $remove_bucket_time seconds" >> ./report/benchmark-delete.txt
      The stdout should include ""
      The status should be success
      ;;
    esac
  End
End

Describe 'Delete large bucket with 10000 objects:' category:"BigBuckets"
  setup(){
    bucket_name="test-093-$(date +%s)"
    files_count=10000
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"093"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    for i in $(seq 1 $files_count); do
      touch ./report/arquivo_$i.txt
    done
    aws --profile $profile s3 sync ./report/ s3://$test_bucket_name > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      start_time=$(date +%s) > /dev/null
      When run bash ./spec/retry_command.sh "aws --profile $profile s3 rb s3://$test_bucket_name --force" 5000
      # When run aws --profile $profile s3 rb s3://$test_bucket_name --force
      end_time=$(date +%s) > /dev/null
      remove_bucket_time=$((end_time - start_time)) > /dev/null
      echo "Time to remove bucket with $files_count files on profile $profile: $remove_bucket_time seconds" >> ./report/benchmark-delete.tap
      The stdout should include ""
      #The stderr should include ""
      The status should be success
      ;;
    "rclone")
      start_time=$(date +%s) > /dev/null
      When run rclone purge $profile:$test_bucket_name
      end_time=$(date +%s) > /dev/null
      remove_bucket_time=$((end_time - start_time)) > /dev/null
      echo "Time to remove bucket with $files_count files on profile $profile: $remove_bucket_time seconds" >> ./report/benchmark-delete.txt
      The stdout should include ""
      The status should be success
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      start_time=$(date +%s) > /dev/null
      When run mgc object-storage buckets delete --recursive --bucket $test_bucket_name
      end_time=$(date +%s) > /dev/null
      remove_bucket_time=$((end_time - start_time)) > /dev/null
      echo "Time to remove bucket with $files_count files on profile $profile: $remove_bucket_time seconds" >> ./report/benchmark-delete.txt
      The stdout should include ""
      The status should be success
      ;;
    esac
  End
End

Describe 'Delete large bucket with 25000 objects:' category:"BigBuckets"
  setup(){
    bucket_name="test-093-$(date +%s)"
    files_count=25000
  }
  Before 'setup' 
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"093"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    for i in $(seq 1 $files_count); do
      touch ./report/arquivo_$i.txt
    done
    aws --profile $profile s3 sync ./report/ s3://$test_bucket_name > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      start_time=$(date +%s) > /dev/null
      When run bash ./spec/retry_command.sh "aws --profile $profile s3 rb s3://$test_bucket_name --force" 5000
      # When run aws --profile $profile s3 rb s3://$test_bucket_name --force
      end_time=$(date +%s) > /dev/null
      remove_bucket_time=$((end_time - start_time)) > /dev/null
      echo "Time to remove bucket with $files_count files on profile $profile: $remove_bucket_time seconds" >> ./report/benchmark-delete.txt
      The stdout should include ""
      #The stderr should include ""
      The status should be success
      ;;
    "rclone")
      start_time=$(date +%s) > /dev/null
      When run rclone purge $profile:$test_bucket_name
      end_time=$(date +%s) > /dev/null
      remove_bucket_time=$((end_time - start_time)) > /dev/null
      echo "Time to remove bucket with $files_count files on profile $profile: $remove_bucket_time seconds" >> ./report/benchmark-delete.txt
      The stdout should include ""
      The status should be success
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      start_time=$(date +%s) > /dev/null
      When run mgc object-storage buckets delete --recursive --bucket $test_bucket_name
      end_time=$(date +%s) > /dev/null
      remove_bucket_time=$((end_time - start_time)) > /dev/null
      echo "Time to remove bucket with $files_count files on profile $profile: $remove_bucket_time seconds" >> ./report/benchmark-delete.txt
      The stdout should include ""
      The status should be success
      ;;
    esac
    cat ./report/benchmark-delete.txt
  End
End
