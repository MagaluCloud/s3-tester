% UNIQUE_SUFIX: $(date +%s)

# import functions: get_test_bucket_name, get_uploaded_key, remove_test_bucket
Include ./spec/053_utils.sh
# import functions: exist_var create_file
Include ./spec/054_utils.sh

# aws dont allow setting public-read canned acl without unblocking access to it first
remove_acl_block() {
  profile=$1
  bucket=$2
  # openstack swift dont block acl setting, early return
  if (aws s3api --profile $profile get-bucket-ownership-controls --bucket $bucket | jq .OwnershipControls |grep '{}' > /dev/null); then
    return
  fi
  # AWS needs unblocking
  aws s3api --profile $profile put-bucket-ownership-controls --bucket $bucket --ownership-controls Rules=[{ObjectOwnership=BucketOwnerPreferred}]
  aws s3api --profile $profile put-public-access-block --bucket $bucket --public-access-block-configuration BlockPublicAcls=false,BlockPublicPolicy=false
}

hard_wait() {
    sleep 3
    aws s3api --profile $profile wait object-exists --bucket $bucket_name --key $object_key
    sleep 3
    aws s3api --profile $profile wait object-exists --bucket $bucket_name --key $object_key
    sleep 3
    aws s3api --profile $profile wait object-exists --bucket $bucket_name --key $object_key
    sleep 3
    aws s3api --profile $profile wait object-exists --bucket $bucket_name --key $object_key
    echo hard wait, $object_key exists on bucket $bucket_name and profile $profile
}
Describe 'Setup 84, 85, 86, 87, 88, 89' category:"ColdStorage"
  Parameters:matrix
    $PROFILES
  End
  Example "create test bucket using rclone" id:"084" id:"085" id:"086" id:"087" id:"088" id:"089"
    profile=$1
    bucket_name=$(get_test_bucket_name)
    When run rclone mkdir "$profile:$bucket_name"
    The status should be success
    remove_acl_block $profile $bucket_name
  End
End

Describe 'Put object with storage class' category:"ColdStorage" id:"084" id:"085" id:"087"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "default, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "default-class")
    file="LICENSE"
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api put-object --bucket "$bucket_name" --key "$object_key" --body "$file"
      The status should be success
      The output should include "\"ETag\":"
      ;;
    "aws-s3")
      When run aws --profile "$profile" s3 cp "$file" "s3://$bucket_name/$object_key"
      The status should be success
      The output should include "upload: ./$file to s3://$bucket_name/$object_key"
      ;;
    "rclone")
      When run rclone copyto "$file" "$profile:$bucket_name/$object_key" -v
      The status should be success
      The error should include "INFO  : $file: Copied"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage objects upload --src "$file" --dst "$bucket_name/$object_key" --raw"
      # When run mgc object-storage objects upload --src "$file" --dst "$bucket_name/$object_key" --raw
      The output should include "$bucket_name"
      The output should include "$file"
      ;;
    esac
  End
  Example "STANDARD, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "standard-class")
    file="LICENSE"    
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api put-object --bucket "$bucket_name" --key "$object_key" --storage-class "STANDARD" --body "$file"
      The status should be success
      The output should include "\"ETag\":"
      ;;
    "aws-s3")
      When run aws --profile "$profile" s3 cp "$file" "s3://$bucket_name/$object_key" --storage-class "STANDARD"
      The status should be success
      The output should include "upload: ./$file to s3://$bucket_name/$object_key"
      ;;
    "rclone")
      When run rclone copyto "$file" "$profile:$bucket_name/$object_key" --s3-storage-class "standard" -v
      The status should be success
      The error should include "INFO  : $file: Copied"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage objects upload --src "$file" --dst "$bucket_name/$object_key" --storage-class=standard --raw"
      # When run mgc object-storage objects upload --src "$file" --dst "$bucket_name/$object_key" --storage-class=standard --raw
      The output should include "$bucket_name"
      The output should include "$file"
      ;;
    esac
  End
  Example "GLACIER_IR, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "glacier-ir-class")
    file="LICENSE"
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api put-object --bucket "$bucket_name" --key "$object_key" --storage-class "GLACIER_IR" --body "$file"
      The status should be success
      The output should include "\"ETag\":"
      ;;
    "aws-s3")
      When run aws --profile "$profile" s3 cp "$file" "s3://$bucket_name/$object_key" --storage-class "GLACIER_IR"
      The status should be success
      The output should include "upload: ./$file to s3://$bucket_name/$object_key"
      ;;
    "rclone")
      When run rclone copyto "$file" "$profile:$bucket_name/$object_key" --s3-storage-class "GLACIER_IR" -v
      The status should be success
      The error should include "INFO  : $file: Copied"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage objects upload --src "$file" --dst "$bucket_name/$object_key" --storage-class=cold_instant --raw"
      # When run mgc object-storage objects upload --src "$file" --dst "$bucket_name/$object_key" --storage-class=cold_instant --raw
      The output should include "$bucket_name"
      The output should include "$file"
      ;;
    esac
  End
End

include_cold_or_glacier() {
  value=${include_cold_or_glacier:?}
  [[ $value == *"GLACIER_IR"* ]] || [[ $value == *"COLD"* ]]
}
Describe 'List object with storage class' category:"ColdStorage" id:"085"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "default, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "default-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws s3api list-objects-v2 --profile "$profile" --bucket "$bucket_name" --prefix "$object_key" --query "Contents[*].StorageClass"
      The status should be success
      The output should include "\"STANDARD\""
      ;;
    "rclone")
      When run rclone lsjson --metadata "$profile:$bucket_name/$object_key"
      The status should be success
      The output should include "STANDARD"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      sleep 10
      When run bash ./spec/retry_command.sh "mgc object-storage objects list "$bucket_name" --output json"
      # When run mgc object-storage objects list "$bucket_name" --raw
      The output should include "$file"
      ;;
    esac
  End
  Example "STANDARD, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "standard-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws s3api list-objects-v2 --profile "$profile" --bucket "$bucket_name" --prefix "$object_key" --query "Contents[*].StorageClass"
      The status should be success
      The output should include "\"STANDARD\""
      ;;
    "rclone")
      sleep 10
      When run rclone lsjson --metadata "$profile:$bucket_name/$object_key"
      The status should be success
      The output should include "STANDARD"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run bash ./spec/retry_command.sh "mgc object-storage objects list "$bucket_name" --output json"
      # When run mgc object-storage objects list "$bucket_name" --raw
      The output should include "STANDARD"
      The output should include "$file"
      ;;
    esac
  End
  Example "COLD or GLACIER_IR, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "glacier-ir-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws s3api list-objects-v2 --profile "$profile" --bucket "$bucket_name" --prefix "$object_key" --query "Contents[*].StorageClass"
      The status should be success
      The output should satisfy include_cold_or_glacier
      ;;
    "rclone")
      sleep 10
      When run rclone lsjson --metadata "$profile:$bucket_name/$object_key"
      The status should be success
      The output should satisfy include_cold_or_glacier
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      sleep 10
      When run bash ./spec/retry_command.sh "mgc object-storage objects list "$bucket_name" --output json"
      # When run mgc object-storage objects list "$bucket_name" --raw
      The output should include "COLD"
      The output should include "$file"
      ;;
    esac
  End
End

Describe 'Object custom metadata with storage class' category:"ColdStorage" id:"088"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "PUT GLACIER_IR, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "glacier-ir-class-with-metadata")
    file="LICENSE"
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api put-object --bucket "$bucket_name" --key "$object_key" --storage-class "GLACIER_IR" --body "$file" --metadata "metadata1=foo,metadata2=bar"
      The status should be success
      The output should include "\"ETag\":"
      ;;
    "aws-s3")
      When run aws --profile "$profile" s3 cp "$file" "s3://$bucket_name/$object_key" --storage-class "GLACIER_IR" --metadata "metadata1=foo,metadata2=bar"
      The status should be success
      The output should include "upload: ./$file to s3://$bucket_name/$object_key"
      ;;
    "rclone")
      When run rclone copyto "$file" "$profile:$bucket_name/$object_key" --s3-storage-class "GLACIER_IR" --header-upload "X-Amz-Meta-Metadata1: foo" --header-upload "X-Amz-Meta-Metadata2: bar" -v
      The status should be success
      The error should include "INFO  : $file: Copied"
      ;;
    "mgc")
      ;;
    esac
  End
  Example "HEAD GLACIER_IR with metadata, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "glacier-ir-class-with-metadata")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws s3api head-object --profile "$profile" --bucket "$bucket_name" --key "$object_key"
      The status should be success
      The output should satisfy include_cold_or_glacier
      The output should include "\"metadata1\": \"foo\""
      The output should include "\"metadata2\": \"bar\""
      The output should include "\"ContentLength\": 1068,"
      ;;
    "rclone")
      When run rclone lsjson --metadata "$profile:$bucket_name/$object_key"
      The status should be success
      The output should satisfy include_cold_or_glacier
      The output should include "\"Size\":1068"
      ;;
    "mgc")
      ;;
    esac
  End
End

Describe 'Multipart upload' category:"ColdStorage" id:"086"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End

  Example "create with storage class default, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-default-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")

    # initiates a multipart upload without passing a storage class argument
    create_multipart() {
      aws s3api create-multipart-upload --profile "$profile" --bucket "$bucket_name" --key "$object_key" | jq .UploadId -r | tee "/tmp/$object_key.upload_id"
    }
    When call create_multipart
    The status should be success
    The output should not equal ""
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End

  Example "create with storage class STANDARD, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-standard-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    # initiates a multipart upload passing a standard storage class argument
    create_standard_multipart() {
      aws s3api create-multipart-upload --profile "$profile" --bucket "$bucket_name" --key "$object_key" --storage-class "STANDARD" | jq .UploadId -r | tee "/tmp/$object_key.upload_id"
    }
    When call create_standard_multipart
    The status should be success
    The output should not equal ""
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End

  Example "create with storage class GLACIER_IR, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-glacier-ir-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    # initiates a multipart upload passing a cold storage class argument
    create_cold_multipart() {
      aws s3api create-multipart-upload --profile "$profile" --bucket "$bucket_name" --key "$object_key" --storage-class "GLACIER_IR" | jq .UploadId -r | tee "/tmp/$object_key.upload_id"
    }
    When call create_cold_multipart
    The status should be success
    The output should not equal ""
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End

  Example "list uploads should list both storage classes, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    count_standard() {
      aws s3api list-multipart-uploads --profile $profile --bucket $bucket_name | jq '[.Uploads[].StorageClass] | sort' | tr -d "\n"
    }
    When call count_standard
    The status should be success
    The output should satisfy include_cold_or_glacier
    The output should include "\"STANDARD\""
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End

  Example "upload parts with storage class default, on profile $1 using client $2"
    profile=$1
    client=$2
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-default-class")
    local_file="" # will be overwritten by the function below
    file_size=6
    file_unit="mb"
    create_file "$file_size" "$file_unit"
    # upload two parts
    upload_id=$(cat "/tmp/$object_key.upload_id")
    aws s3api upload-part --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id "$upload_id" --body "$local_file" --part-number 1 > /dev/null
    When run aws s3api upload-part --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id "$upload_id" --body "$local_file" --part-number 2
    The status should be success
    The output should include "\"ETag\":"
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End

  Example "upload parts with storage class STANDARD, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-standard-class")
    local_file="" # will be overwritten by the function below
    file_size=6
    file_unit="mb"
    create_file "$file_size" "$file_unit"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    # upload two parts
    upload_id=$(cat "/tmp/$object_key.upload_id")
    aws s3api upload-part --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id "$upload_id" --body "$local_file" --part-number 1 > /dev/null
    When run aws s3api upload-part --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id "$upload_id" --body "$local_file" --part-number 2
    The status should be success
    The output should include "\"ETag\":"
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End

  Example "upload parts with storage class GLACIER_IR, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-glacier-ir-class")
    local_file="" # will be overwritten by the function below
    file_size=6
    file_unit="mb"
    create_file "$file_size" "$file_unit"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    # upload two parts
    upload_id=$(cat "/tmp/$object_key.upload_id")
    aws s3api upload-part --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id "$upload_id" --body "$local_file" --part-number 1 > /dev/null
    When run aws s3api upload-part --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id "$upload_id" --body "$local_file" --part-number 2
    The status should be success
    The output should include "\"ETag\":"
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End


  Example "list parts with default storage, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-default-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    upload_id=$(cat "/tmp/$object_key.upload_id")
    When run aws s3api list-parts --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id "$upload_id"
    The status should be success
    The output should include "\"STANDARD\""
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End
  Example "list parts with storage class STANDARD, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-standard-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    upload_id=$(cat "/tmp/$object_key.upload_id")
    When run aws s3api list-parts --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id "$upload_id"
    The status should be success
    The output should include "\"STANDARD\""
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End
  Example "list parts with storage class GLACIER_IR, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-glacier-ir-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    upload_id=$(cat "/tmp/$object_key.upload_id")
    When run aws s3api list-parts --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id "$upload_id"
    The status should be success
    The output should satisfy include_cold_or_glacier
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End


  Example "complete with storage class default, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-default-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    upload_id=$(cat "/tmp/$object_key.upload_id")
    aws s3api list-parts --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id "$upload_id" | jq '{"Parts": [.Parts[] | {"PartNumber": .PartNumber, "ETag": .ETag}]}' > /tmp/parts.json
    When run aws s3api complete-multipart-upload --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id $upload_id --multipart-upload file:///tmp/parts.json
    The status should be success
    The output should include "\"Key\": \"$object_key\""
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End

  Example "complete with storage class STANDARD, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-standard-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    upload_id=$(cat "/tmp/$object_key.upload_id")
    # generates a parts list json file
    aws s3api list-parts --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id "$upload_id" | jq '{"Parts": [.Parts[] | {"PartNumber": .PartNumber, "ETag": .ETag}]}' > /tmp/parts.json
    # complete the multipart upload
    When run aws s3api complete-multipart-upload --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id $upload_id --multipart-upload file:///tmp/parts.json
    The status should be success
    The output should include "\"Key\": \"$object_key\""
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End

  Example "complete with storage class GLACIER_IR, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-glacier-ir-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
    upload_id=$(cat "/tmp/$object_key.upload_id")
    # generates a parts list json file
    aws s3api list-parts --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id "$upload_id" | jq '{"Parts": [.Parts[] | {"PartNumber": .PartNumber, "ETag": .ETag}]}' > /tmp/parts.json
    # complete the multipart upload
    When run aws s3api complete-multipart-upload --profile "$profile" --bucket "$bucket_name" --key "$object_key" --upload-id $upload_id --multipart-upload file:///tmp/parts.json
    The status should be success
    The output should include "\"Key\": \"$object_key\""
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End
End

Describe 'Multipart upload' category:"ColdStorage" id:"086"
  Parameters:matrix
    $PROFILES
    mgc
  End

  # This is same as previous tests, but mgc cli does all operations as one
  Example "upload with storage class default, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-default-class")
    local_file="" # will be overwritten by the function below
    file_size=6
    file_unit="mb"
    create_file "$file_size" "$file_unit"
    mgc workspace set $profile > /dev/null
    When run bash ./spec/retry_command.sh "mgc object-storage objects upload --src "$local_file" --dst "$bucket_name/$object_key" --raw"
    The status should be success
    The output should include "$bucket_name/$file"
  End

  Example "upload with storage class STANDARD, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-standard-class")
    local_file="" # will be overwritten by the function below
    file_size=6
    file_unit="mb"
    create_file "$file_size" "$file_unit"
    mgc workspace set $profile > /dev/null
    When run mgc object-storage objects upload --src "$local_file" --dst "$bucket_name/$object_key" --storage-class standard --raw
    The status should be success
    The output should include "$bucket_name/$file"
  End
  Example "upload with storage class GLACIER_IR, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-glacier-ir-class")
    local_file="" # will be overwritten by the function below
    file_size=6
    file_unit="mb"
    create_file "$file_size" "$file_unit"
    mgc workspace set $profile > /dev/null
    When run mgc object-storage objects upload "$local_file" "$bucket_name/$object_key" --storage-class glacier_ir --raw
    The status should be success
    The output should include "$bucket_name/$file"
  End
  Example "upload with storage class COLD, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-cold-class")
    local_file="" # will be overwritten by the function below
    file_size=6
    file_unit="mb"
    create_file "$file_size" "$file_unit"
    mgc workspace set $profile > /dev/null
    When run mgc object-storage objects upload "$local_file" "$bucket_name/$object_key" --storage-class cold_instant --raw
    The status should be success
    The output should include "$bucket_name/$file"
  End
End

Describe 'List multipart object with storage class' category:"ColdStorage" id:"086"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "default, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-default-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws s3api list-objects-v2 --profile "$profile" --bucket "$bucket_name" --prefix "$object_key" --query "Contents[*].StorageClass"
      The status should be success
      The output should include "\"STANDARD\""
      ;;
    "rclone")
      # When run rclone lsjson --metadata "$profile:$bucket_name/$object_key"
      # The status should be success
      # The output should include "STANDARD"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      sleep 10
      When run bash ./spec/retry_command.sh "mgc object-storage objects list "$bucket_name" --output json"
      # When run mgc object-storage objects list "$bucket_name" --raw
      The output should include "$object_key"
      ;;
    esac
  End
  Example "STANDARD, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-standard-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws s3api list-objects-v2 --profile "$profile" --bucket "$bucket_name" --prefix "$object_key" --query "Contents[*].StorageClass"
      The status should be success
      The output should include "\"STANDARD\""
      ;;
    "rclone")
      # When run rclone lsjson --metadata "$profile:$bucket_name/$object_key"
      # The status should be success
      # The output should include "STANDARD"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      sleep 10
      When run bash ./spec/retry_command.sh "mgc object-storage objects list "$bucket_name" --output json"
      # When run mgc object-storage objects list "$bucket_name" --raw
      The output should include "$object_key"
      ;;
    esac
  End
  Example "GLACIER_IR, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "multipart-glacier-ir-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws s3api list-objects-v2 --profile "$profile" --bucket "$bucket_name" --prefix "$object_key" --query "Contents[*].StorageClass"
      The status should be success
      The output should satisfy include_cold_or_glacier
      ;;
    "rclone")
      # When run rclone lsjson --metadata "$profile:$bucket_name/$object_key"
      # The status should be success
      # The output should include "GLACIER_IR"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      sleep 10
      When run bash ./spec/retry_command.sh "mgc object-storage objects list "$bucket_name" --output json"
      # When run mgc object-storage objects list "$bucket_name" --raw
      The output should include "$object_key"
      The output should include "COLD"
      ;;
    esac
  End
End

Describe 'Change the storage class of an existing…' category:"ColdStorage" id:"087"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End

  Example "default object to GLACIER_IR on $1 using $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "default-class")
    new_object_key=$(get_uploaded_key "default-class")
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api copy-object --bucket "$bucket_name" --key "$new_object_key" --storage-class "GLACIER_IR" --copy-source "$bucket_name/$object_key"
      The status should be success
      The output should include "\"ETag\":"
      ;;
    "aws-s3")
      When run aws --profile "$profile" s3 cp "s3://$bucket_name/$object_key" "s3://$bucket_name/$new_object_key" --storage-class "GLACIER_IR"
      The status should be success
      The output should include "copy: s3://$bucket_name/$object_key to s3://$bucket_name/$new_object_key"
      ;;
    "rclone")
      When run rclone settier "GLACIER_IR" "$profile:$bucket_name/$object_key" --dump headers
      The status should be success
      The error should include "X-Amz-Storage-Class: GLACIER_IR"
      ;;
    "mgc")
      ;;
    esac
  End
  Example "STANDARD object to GLACIER_IR on $1 using $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "standard-class")
    new_object_key=$(get_uploaded_key "standard-class")
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api copy-object --bucket "$bucket_name" --key "$new_object_key" --storage-class "GLACIER_IR" --copy-source "$bucket_name/$object_key"
      The status should be success
      The output should include "\"ETag\":"
      ;;
    "aws-s3")
      When run aws --profile "$profile" s3 cp "s3://$bucket_name/$object_key" "s3://$bucket_name/$new_object_key" --storage-class "GLACIER_IR"
      The status should be success
      The output should include "copy: s3://$bucket_name/$object_key to s3://$bucket_name/$new_object_key"
      ;;
    "rclone")
      When run rclone settier "GLACIER_IR" "$profile:$bucket_name/$object_key" --dump headers
      The status should be success
      The error should include "X-Amz-Storage-Class: GLACIER_IR"
      ;;
    "mgc")
      ;;
    esac
  End
#  Example "GLACIER_IR object to default (no storage class) on $1 using $2"
#    profile=$1
#    client=$2
#    bucket_name=$(get_test_bucket_name)
#    object_key=$(get_uploaded_key "glacier-ir-class")
#    new_object_key=$(get_uploaded_key "glacier-ir-class")
#    case "$client" in
#    "aws-s3api" | "aws")
#      When run aws --profile "$profile" s3api copy-object --bucket "$bucket_name" --key "$new_object_key" --copy-source "$bucket_name/$object_key"
#      The status should not be success
#      The error should include "(InvalidRequest)"
#      ;;
#    "aws-s3")
#      When run aws --profile "$profile" s3 cp "s3://$bucket_name/$object_key" "s3://$bucket_name/$new_object_key"
#      The status should not be success
#      The error should include "(InvalidRequest)"
#      ;;
#    "rclone")
#      # When run rclone settier "" "$profile:$bucket_name/$object_key" --dump headers
#      # The status should be success
#      # The error should include "X-Amz-Storage-Class: STANDARD"
#      ;;
#    "mgc")
#      ;;
#    esac
#  End
  Example "GLACIER_IR object to STANDARD on $1 using $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "glacier-ir-class")
    new_object_key=$(get_uploaded_key "glacier-ir-class")
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api copy-object --bucket "$bucket_name" --key "$new_object_key" --storage-class "STANDARD" --copy-source "$bucket_name/$object_key"
      The status should be success
      The output should include "\"ETag\":"
      ;;
    "aws-s3")
      When run aws --profile "$profile" s3 cp "s3://$bucket_name/$object_key" "s3://$bucket_name/$new_object_key" --storage-class "STANDARD"
      The status should be success
      The output should include "copy: s3://$bucket_name/$object_key to s3://$bucket_name/$new_object_key"
      ;;
    "rclone")
      When run rclone settier "STANDARD" "$profile:$bucket_name/$object_key" --dump headers
      The status should be success
      The error should include "X-Amz-Storage-Class: STANDARD"
      ;;
    "mgc")
      ;;
    esac
  End
End

Describe 'List object with changed storage class' category:"ColdStorage" id:"087"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "old default, now GLACIER_IR on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "default-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws s3api list-objects-v2 --profile "$profile" --bucket "$bucket_name" --prefix "$object_key" --query "Contents[*].StorageClass"
      The status should be success
      The output should satisfy include_cold_or_glacier
      ;;
    "rclone")
      When run rclone lsjson --metadata "$profile:$bucket_name/$object_key"
      The status should be success
      The output should satisfy include_cold_or_glacier
      ;;
    "mgc")
      ;;
    esac
  End
  Example "old STANDARD, now GLACIER_IR on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "standard-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws s3api list-objects-v2 --profile "$profile" --bucket "$bucket_name" --prefix "$object_key" --query "Contents[*].StorageClass"
      The status should be success
      The output should satisfy include_cold_or_glacier
      ;;
    "rclone")
      When run rclone lsjson --metadata "$profile:$bucket_name/$object_key"
      The status should be success
      The output should satisfy include_cold_or_glacier
      ;;
    "mgc")
      ;;
    esac
  End
  Example "old GLACIER_IR, now STANDARD on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "glacier-ir-class")
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      hard_wait
      When run aws s3api list-objects-v2 --profile "$profile" --bucket "$bucket_name" --prefix "$object_key" --query "Contents[*].StorageClass"
      The status should be success
      The output should include "\"STANDARD\""
      ;;
    "rclone")
      hard_wait
      When run rclone lsjson --metadata "$profile:$bucket_name/$object_key"
      Dump
      The status should be success
      The output should include "STANDARD"
      ;;
    "mgc")
      ;;
    esac
  End
End

Describe 'Put object with ACL and storage class' category:"ColdStorage" id:"089"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "default, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "default-class-with-acl")
    file="LICENSE"
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api put-object --bucket "$bucket_name" --key "$object_key" --body "$file" --acl public-read
      The status should be success
      The output should include "\"ETag\":"
      ;;
    "aws-s3")
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End
  Example "STANDARD, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "standard-class-with-acl")
    file="LICENSE"
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api put-object --bucket "$bucket_name" --key "$object_key" --body "$file" --acl public-read --storage-class "STANDARD"
      The status should be success
      The output should include "\"ETag\":"
      ;;
    "aws-s3")
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End
  Example "GLACIER_IR, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "glacier-ir-class-with-acl")
    file="LICENSE"
    case "$client" in
    "aws-s3api" | "aws")
      When run aws --profile "$profile" s3api put-object --bucket "$bucket_name" --key "$object_key" --body "$file" --acl public-read --storage-class "GLACIER_IR"
      The status should be success
      The output should include "\"ETag\":"
      ;;
    "aws-s3")
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End
End
Describe 'GET object ACL and storage class' category:"ColdStorage" id:"089"
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  # asserts that the storage class is the expected, if grep fails the test fails
  wrong_storage_class() {
    echo "ERROR: Unexpected storage class"
    exit 1
  }
  Example "default, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "default-class-with-acl")
    file="LICENSE"
    case "$client" in
    "aws-s3api" | "aws")
      trap wrong_storage_class ERR
      aws --profile "$profile" s3api get-object-attributes --object-attributes StorageClass --bucket "$bucket_name" --key "$object_key" | grep STANDARD > /dev/null
      When run aws --profile "$profile" s3api get-object-acl --bucket "$bucket_name" --key "$object_key"
      The status should be success
      The output should include "\"Permission\": \"READ\""
      ;;
    "aws-s3")
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End
  Example "STANDARD, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "standard-class-with-acl")
    file="LICENSE"
    case "$client" in
    "aws-s3api" | "aws")
      trap wrong_storage_class ERR
      aws --profile "$profile" s3api get-object-attributes --object-attributes StorageClass --bucket "$bucket_name" --key "$object_key" | grep STANDARD > /dev/null
      When run aws --profile "$profile" s3api get-object-acl --bucket "$bucket_name" --key "$object_key"
      The status should be success
      The output should include "\"Permission\": \"READ\""
      ;;
    "aws-s3")
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End
  Example "GLACIER_IR, on profile $1 using client $2"
    profile=$1
    client=$2
    bucket_name=$(get_test_bucket_name)
    object_key=$(get_uploaded_key "glacier-ir-class-with-acl")
    file="LICENSE"
    case "$client" in
    "aws-s3api" | "aws")
      # asserts that the storage class is the expected, if grep fails the test fails
      trap wrong_storage_class ERR
      aws --profile "$profile" s3api get-object-attributes --object-attributes StorageClass --bucket "$bucket_name" --key "$object_key" | grep -E 'GLACIER_IR|COLD' > /dev/null
      When run aws --profile "$profile" s3api get-object-acl --bucket "$bucket_name" --key "$object_key"
      The status should be success
      The output should include "\"Permission\": \"READ\""
      ;;
    "aws-s3")
      ;;
    "rclone")
      ;;
    "mgc")
      ;;
    esac
  End
End

teardown(){
  remove_test_bucket $profile $UNIQUE_SUFIX
}
Describe 'Teardown 84, 85, 86, 87, 88, 89'
  Parameters:matrix
    $PROFILES
  End
  Example "remove test bucket or test bucket contents" id:"085" id:"086" id:"087" id:"088" id:"089"
    profile=$1
    When call teardown
    The status should be success
  End
End
