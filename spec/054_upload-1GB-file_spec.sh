# Upload, Download big objects
#
# The test 054 is required for test 058 so they are linked. Filtering by the
# later will also run the former. Test 54 is the "setup" for test 58. The same
# is true for 055+059 and 056+060.
#
# The Download tests (058,059,060) also accepts an env var with `bucket/key`
# names, if passed the upload part is skipped, see env var names below.
#
# You can also use an env var to test with smaller sizes, use mb as size unit instead of gb
# Tests:
#   - "054 Upload Files of  1GB" and "058 Download Files of  1GB"
#   - "055 Upload Files of  5GB" and "059 Download Files of  5GB"
#   - "056 Upload Files of 10GB" and "060 Download Files of 10GB"
#
# Env vars (optional):
#
#| Name               | Example                | Description                                 |
#|--------------------|------------------------|---------------------------------------------|
#| $TEST_BUCKET_NAME  | mybucketname           | an existing bucket to be reused             |
#| $SIZE_UNIT         | mb                     | uses 1, 5, 10 Mb istead of Gb               |
#| $OBJECT_URI_1GB    | mybucketname/my1GBkey  | an existing object of 1GB to be downloaded  |
#| $OBJECT_URI_5GB    | mybucketname/my5GBkey  | an existing object of 5GB to be downloaded  |
#| $OBJECT_URI_10GB   | mybucketname/my10Gkey  | an existing object of 10GB to be downloaded |
#
#-------------------------------------------------------------------------------

# import functions: get_test_bucket_name, create_test_bucket, remove_test_bucket
Include ./spec/053_utils.sh
# import functions: exist_var create_file
Include ./spec/054_utils.sh

# constants
% UNIQUE_SUFIX: $(date +%s)

Describe 'Setup 54,55,56,58,59,60' category:"BigObjects" category:"slow"
  Parameters:matrix
    $PROFILES
  End
  Example "create test bucket" id:"054" id:"055" id:"056" id:"058" id:"059" id:"060"
    profile=$1
    bucket_name=$(get_test_bucket_name)
    # rclone wont exit 1 even if the bucket exists, which makes this action indepotent
    When run rclone mkdir "$profile:$bucket_name"
    The status should be success
  End
End


file_size="1"
file_unit=${SIZE_UNIT:-"gb"}
Describe "of size ${file_size}${file_unit}" category:"BigObjects" category:"slow"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Describe "Upload Files" id:"054" id:"058"
    Skip if "Uploaded file exists" exists_var "OBJECT_URI_1GB"
    Example "on profile $1, using client $2, upload $file_size$file_unit to bucket $BUCKET_NAME"
      create_file "$file_size" "$file_unit"
      profile=$1
      client=$2
      BUCKET_NAME=$(get_test_bucket_name)
      key="test-${profile}__${client}__${filename}"
      case "$client" in
      "aws-s3api" | "aws")
        When run aws --profile $profile s3api put-object --bucket $BUCKET_NAME --body $local_file --key $key
        The status should be success
        The output should include "ETag"
        ;;
      "aws-s3")
        When run aws --profile $profile s3 cp $local_file "s3://$BUCKET_NAME/$key"
        The status should be success
        The output should include "upload: "
        The output should include "$local_file to s3://$BUCKET_NAME/$key"
        ;;
      "rclone")
        When run rclone copyto $local_file $profile:$BUCKET_NAME/$key --no-check-dest -v
        The status should be success
        The error should include " Copied"
        The error should include "to: $key"
        ;;
      "mgc")
        mgc workspace set $profile > /dev/null
        When run bash ./spec/retry_command.sh "mgc object-storage objects upload --src="$local_file" --dst="$BUCKET_NAME/$key" --raw"
        #When run mgc object-storage objects upload --src="$local_file" --dst="$BUCKET_NAME/$key" --raw
        The status should be success
        The output should include "$filename"
        The output should include "$BUCKET_NAME/$key"
        ;;
      esac
      rm $local_file
      # Assert that the file was uploaded by waiting for object-exists
      aws s3api --profile $profile wait object-exists --bucket $BUCKET_NAME --key $key
    End
  End
  Describe "Download Files" category:"BigObjects" category:"slow"
    Example "on profile $1, using client $2, download $file_size$file_unit from bucket $BUCKET_NAME" id:"058"
      profile=$1
      client=$2
      BUCKET_NAME=$(get_test_bucket_name)
      key="test-${profile}__${client}__${filename}"
      out_file="/tmp/$key"
      case "$client" in
      "aws-s3api" | "aws")
        When run aws --profile $profile s3api get-object --bucket $BUCKET_NAME --key $key $out_file
        The status should be success
        The output should include "ETag"
        ;;
      "aws-s3")
        When run aws --profile $profile s3 cp "s3://$BUCKET_NAME/$key" $out_file
        The status should be success
        The output should include "download: s3://$BUCKET_NAME/$key"
        The output should include "$out_file"
        ;;
      "rclone")
        When run rclone copyto $profile:$BUCKET_NAME/$key $out_file -v --no-check-dest
        The status should be success
        The error should include "$object_key: "
        The error should include "Copied"
        The error should include ", 100%"
        ;;
      "mgc")
        mgc workspace set $profile > /dev/null
        When run bash ./spec/retry_command.sh "mgc object-storage objects download --dst="$out_file" --src="$BUCKET_NAME/$key" --raw"
        # When run mgc object-storage objects download --dst="$out_file" --src="$BUCKET_NAME/$key" --raw
        The status should be success
        The output should include "$BUCKET_NAME/$key"
        The output should include "$out_file"
        ;;
      esac
      rm $out_file
    End
  End
End

file_size="5"
Describe "of size ${file_size}${file_unit}" category:"BigObjects" category:"slow"

  Parameters:matrix
    $PROFILES
    $CLIENTS
  End

  Describe "Upload Files" id:"055" id:"059"
    Skip if "Uploaded file exists" exists_var "OBJECT_URI_5GB"
    Example "on profile $1, using client $2, upload $file_size$file_unit to bucket $BUCKET_NAME"
      create_file "$file_size" "$file_unit"
      profile=$1
      client=$2
      BUCKET_NAME=$(get_test_bucket_name)
      key="test-${profile}__${client}__${filename}"
      case "$client" in
      "aws-s3api" | "aws")
        When run aws --profile $profile s3api put-object --bucket $BUCKET_NAME --body $local_file --key $key
        The status should be success
        The output should include "ETag"
        ;;
      "aws-s3")
        When run aws --profile $profile s3 cp $local_file "s3://$BUCKET_NAME/$key"
        The status should be success
        The output should include "upload: "
        The output should include "$local_file to s3://$BUCKET_NAME/$key"
        ;;
      "rclone")
        When run rclone copyto $local_file $profile:$BUCKET_NAME/$key --no-check-dest -v
        The status should be success
        The error should include " Copied"
        The error should include "to: $key"
        ;;
      "mgc")
        mgc workspace set $profile > /dev/null
        When run bash ./spec/retry_command.sh "mgc object-storage objects upload --src="$local_file" --dst="$BUCKET_NAME/$key" --raw"
        # When run mgc object-storage objects upload --src="$local_file" --dst="$BUCKET_NAME/$key" --raw
        The status should be success
        The output should include "$filename"
        The output should include "$BUCKET_NAME/$key"
        ;;
      esac
      rm $local_file
      # Assert that the file was uploaded by waiting for object-exists
      aws s3api --profile $profile wait object-exists --bucket $BUCKET_NAME --key $key
    End
  End
  Describe "Download Files" category:"BigObjects" category:"slow"
    Example "on profile $1, using client $2, download $file_size$file_unit from bucket $BUCKET_NAME" id:"059"
      profile=$1
      client=$2
      BUCKET_NAME=$(get_test_bucket_name)
      key="test-${profile}__${client}__${filename}"
      out_file="/tmp/$key"
      case "$client" in
      "aws-s3api" | "aws")
        When run aws --profile $profile s3api get-object --bucket $BUCKET_NAME --key $key $out_file
        The status should be success
        The output should include "ETag"
        ;;
      "aws-s3")
        When run aws --profile $profile s3 cp "s3://$BUCKET_NAME/$key" $out_file
        The status should be success
        The output should include "download: s3://$BUCKET_NAME/$key"
        The output should include "$out_file"
        ;;
      "rclone")
        When run rclone copyto $profile:$BUCKET_NAME/$key $out_file -v --no-check-dest
        The status should be success
        The error should include "$object_key: "
        The error should include "Copied"
        The error should include ", 100%"
        ;;
      "mgc")
        mgc workspace set $profile > /dev/null
        When run bash ./spec/retry_command.sh "mgc object-storage objects download --dst="$out_file" --src="$BUCKET_NAME/$key" --raw"
        # When run mgc object-storage objects download --dst="$out_file" --src="$BUCKET_NAME/$key" --raw
        The status should be success
        The output should include "$BUCKET_NAME/$key"
        The output should include "$out_file"
        ;;
      esac
      rm $out_file
    End
  End
End
file_size="10"
Describe "of size ${file_size}${file_unit}" category:"BigObjects" category:"slow"

  Parameters:matrix
    $PROFILES
    $CLIENTS
  End

  Describe "Upload Files" id:"056" id:"060"
    Skip if "Uploaded file exists" exists_var "OBJECT_URI_10GB"
    Example "on profile $1, using client $2, upload $file_size$file_unit to bucket $BUCKET_NAME"
      create_file "$file_size" "$file_unit"
      profile=$1
      client=$2
      BUCKET_NAME=$(get_test_bucket_name)
      key="test-${profile}__${client}__${filename}"
      case "$client" in
      "aws-s3api" | "aws")
        When run aws --profile $profile s3api put-object --bucket $BUCKET_NAME --body $local_file --key $key
        The status should be success
        The output should include "ETag"
        ;;
      "aws-s3")
        When run aws --profile $profile s3 cp $local_file "s3://$BUCKET_NAME/$key"
        The status should be success
        The output should include "upload: "
        The output should include "$local_file to s3://$BUCKET_NAME/$key"
        ;;
      "rclone")
        When run rclone copyto $local_file $profile:$BUCKET_NAME/$key --no-check-dest -v
        The status should be success
        The error should include " Copied"
        The error should include "to: $key"
        ;;
      "mgc")
        mgc workspace set $profile > /dev/null
        When run bash ./spec/retry_command.sh "mgc object-storage objects upload --src="$local_file" --dst="$BUCKET_NAME/$key" --raw"
        # When run mgc object-storage objects upload --src="$local_file" --dst="$BUCKET_NAME/$key" --raw
        The status should be success
        The output should include "$filename"
        The output should include "$BUCKET_NAME/$key"
        ;;
      esac
      rm $local_file
      # Assert that the file was uploaded by waiting for object-exists
      aws s3api --profile $profile wait object-exists --bucket $BUCKET_NAME --key $key
    End
  End
  Describe "Download Files"
    Example "on profile $1, using client $2, download $file_size$file_unit from bucket $BUCKET_NAME" id:"060"
      profile=$1
      client=$2
      BUCKET_NAME=$(get_test_bucket_name)
      key="test-${profile}__${client}__${filename}"
      out_file="/tmp/$key"
      case "$client" in
      "aws-s3api" | "aws")
        When run aws --profile $profile s3api get-object --bucket $BUCKET_NAME --key $key $out_file
        The status should be success
        The output should include "ETag"
        ;;
      "aws-s3")
        When run aws --profile $profile s3 cp "s3://$BUCKET_NAME/$key" $out_file
        The status should be success
        The output should include "download: s3://$BUCKET_NAME/$key"
        The output should include "$out_file"
        ;;
      "rclone")
        When run rclone copyto $profile:$BUCKET_NAME/$key $out_file -v --no-check-dest
        The status should be success
        The error should include "$object_key: "
        The error should include "Copied"
        The error should include ", 100%"
        ;;
      "mgc")
        mgc workspace set $profile > /dev/null
        When run bash ./spec/retry_command.sh "mgc object-storage objects download --dst="$out_file" --src="$BUCKET_NAME/$key" --raw"
        # When run mgc object-storage objects download --dst="$out_file" --src="$BUCKET_NAME/$key" --raw
        The status should be success
        The output should include "$BUCKET_NAME/$key"
        The output should include "$out_file"
        ;;
      esac
      rm $out_file
    End
  End
End

teardown(){
  remove_test_bucket $profile
}
Describe 'Teardown 54,55,56,58,59,60' category:"BigObjects" category:"slow"
  Parameters:matrix
    $PROFILES
  End
  Example "remove test bucket if it was recently created" id:"054" id:"055" id:"056" id:"058" id:"059" id:"060"
    profile=$1
    When call teardown
    The status should be success
  End
End
