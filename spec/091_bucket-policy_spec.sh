# Constants
% PRINCIPAL_LIST: "\"*\" CanonicalUser"

# import functions: wait_command
Include ./spec/019_utils.sh
is_variable_null() {
  [ -z "$1" ]
}

has_s3_block_public_access() {
    aws s3api --profile $profile get-public-access-block --bucket $test_bucket_name | jq -r '.PublicAccessBlockConfiguration.BlockPublicAcls'
}

setup_policy(){
    local bucket_name=$1
    local client=$2
    local profile=$3
    aws --profile $profile s3 mb s3://$bucket_name > /dev/null
    aws --profile $profile s3 cp $file1_name s3://$bucket_name > /dev/null
    local get_access=$(has_s3_block_public_access)
    if [ $get_access = true ];then
      aws s3api --profile $profile put-bucket-ownership-controls --bucket $bucket_name --ownership-controls="Rules=[{ObjectOwnership=BucketOwnerPreferred}]" > /dev/null
      aws s3api --profile $profile put-public-access-block --bucket $bucket_name --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false > /dev/null
      policy_factory true
    else
      policy_factory false
    fi
}

policy_factory(){
    local prefix=$1
    resource_list=()
    for res in "${resource[@]}"; do
      if [ "$prefix" = true ]; then
        resource_list+="\"arn:aws:s3:::$res\","
      else
        resource_list+="\"$res\","
      fi
    done
    version_num="2012-10-17"
    resource_list=${resource_list%,}
    if [ "$principal" = "*" ]; then
      local principal_entry="\"Principal\": \"*\""
    else
      if [ "$principal" = "CanonicalUser" ]; then
        principal=$(aws s3api --profile $profile list-buckets | jq -r '.Owner.ID')
      fi
      if [ "$prefix" = true ]; then
        local principal_entry="\"Principal\": {\"CanonicalUser\": \"$principal\"}"
      else
        local principal_entry="\"Principal\": {\"MGC\": \"${principal%%:*}\"}"
      fi
    fi
    if [ ! "$action" = '"s3:*"' ]; then #action can't be ["s3:*"], has to be "s3:*" outside the list
      action="[$action]"
    fi
    cat <<EOF
{
    "Version": "$version_num",
    "Statement": [
        {
            "Effect": "$effect",
            $principal_entry,
            "Action": $action,
            "Resource": [$resource_list]
        }
    ]
}
EOF
  }

policy-without() {
  local policy=$1
  local removing_field=$(echo $2 | tr -d \":)
  echo $policy | jq "{Version, Statement: .Statement | map(del(.$removing_field))}"
}

policy-with-empty() {
  local policy=$1
  local affected_field=$(echo $2 | tr -d \":)
  echo $policy | jq ".Statement[].$affected_field"
}


Describe 'Put bucket policy:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
    $PRINCIPAL_LIST
  End
  Example "on profile $1 using client $2 for principal $(echo $3 | tr -d \"):" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    principal=$(echo $3 | tr -d \")
    #policy vars
    action='"s3:GetObject"'
    resource="$test_bucket_name/*"
    effect="Allow"
    policy=$(setup_policy $test_bucket_name $client $profile)
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The stdout should include ""
      The status should be success
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The stdout should include ""
      The status should be success
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    aws --profile $profile s3api delete-bucket-policy --bucket $test_bucket_name > /dev/null
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Delete bucket policy:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    principal="*"
    resource="$test_bucket_name/*"
    effect="Allow"
    policy=$(setup_policy $test_bucket_name $client $profile)
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api delete-bucket-policy --bucket "$test_bucket_name"
      The stdout should include ""
      The status should be success
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy delete --dst $test_bucket_name
      The stdout should include ""
      The status should be success
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    aws --profile $profile s3api delete-bucket-policy --bucket $test_bucket_name
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Easy public bucket policy:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:ListBucket","s3:GetObject"'
    principal="*"
    resource=("$test_bucket_name" "$test_bucket_name/*")
    effect="Allow"
    policy=$(setup_policy $test_bucket_name $client $profile)
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The stdout should include ""
      The status should be success
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The stdout should include ""
      The status should be success
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    aws --profile $profile s3api delete-bucket-policy --bucket $test_bucket_name
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Validate List Easy public bucket policy:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    id=$(aws s3api --profile $profile list-buckets | jq -r '.Owner.ID')
    # if $(is_variable_null "$id_principal"); then return; fi # ! SKIP DOES NOT SKIP
    #policy vars
    action='"s3:ListBucket","s3:GetObject"'
    principal="*"
    resource=("$test_bucket_name" "$test_bucket_name/*")
    effect="Allow"
    policy=$(setup_policy $test_bucket_name $client $profile)
    wait_command bucket-exists $profile "$test_bucket_name"
    aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy" > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run bash ./spec/retry_command.sh "aws --profile $profile-second s3api list-objects-v2 --bucket $test_bucket_name"
      The stdout should include $file1_name
      The status should be success
      ;;
    "rclone")
      When run bash ./spec/retry_command.sh "rclone ls $profile-second:$test_bucket_name"
      The stdout should include $file1_name
      The status should be success
      ;;
    "mgc")
      mgc workspace set $profile-second > /dev/null
      When run bash ./spec/retry_command.sh "mgc os objects list $test_bucket_name"
      The stdout should include $file1_name
      The status should be success
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    aws --profile $profile s3api delete-bucket-policy --bucket "$test_bucket_name" > /dev/null
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Validate Get Easy public bucket policy:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    id=$(aws s3api --profile $profile list-buckets | jq -r '.Owner.ID')
    # if $(is_variable_null "$id_principal"); then return; fi # ! SKIP DOES NOT SKIP
    action='"s3:ListBucket","s3:GetObject"'
    principal="*"
    resource=("$test_bucket_name" "$test_bucket_name/*")
    effect="Allow"
    policy=$(setup_policy $test_bucket_name $client $profile)
    wait_command bucket-exists $profile "$test_bucket_name"
    aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy" > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run bash ./spec/retry_command.sh "aws --profile $profile-second s3 cp s3://$test_bucket_name/$file1_name $file1_name-3"
      The stdout should include $file1_name
      The status should be success
      ;;
    "rclone")
      #When run bash ./spec/retry_command.sh "rclone copy $profile-second:$test_bucket_name/$file1_name $file1_name-3"
      #The stdout should include ""
      #The status should be success
      Skip "Skipped test to $client"
      ;;
    "mgc")
      Skip "Skipped test to $client"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    aws --profile $profile s3api delete-bucket-policy --bucket "$test_bucket_name" > /dev/null
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Buckets exclusive to a specific team:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    id_principal=$(aws --profile $profile-second s3api list-buckets | jq -r '.Owner.ID')
    Skip if "No such a "$profile" user" is_variable_null "$id_principal"
    if $(is_variable_null "$id_principal"); then return; fi # ! SKIP DOES NOT SKIP
    principal="$id_principal"
    resource="$test_bucket_name/*"
    effect="Allow"
    policy=$(setup_policy $test_bucket_name $client $profile)
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The stdout should include ""
      The status should be success
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The stdout should include ""
      The status should be success
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    aws --profile $profile s3api delete-bucket-policy --bucket "$test_bucket_name" > /dev/null
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Validate Buckets exclusive to a specific team:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    id_principal=$(aws --profile $profile-second s3api list-buckets | jq -r '.Owner.ID')
    Skip if "No such a "$profile" user" is_variable_null "$id_principal"
    if $(is_variable_null "$id_principal"); then return; fi # ! SKIP DOES NOT SKIP
    principal="$id_principal"
    resource="$test_bucket_name/*"
    effect="Allow"
    policy=$(setup_policy $test_bucket_name $client $profile)
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy" > /dev/null
      When run bash ./spec/retry_command.sh "aws --profile $profile-second s3 cp s3://$test_bucket_name/$file1_name $file1_name-2"
      The stdout should include $file1_name
      The status should be success
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      Skip "Skipped test to $client"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    aws --profile $profile s3api delete-bucket-policy --bucket "$test_bucket_name" > /dev/null
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Alternative to object-lock:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:DeleteObject"'
    principal="*"
    resource="$test_bucket_name/$file1_name"
    effect="Deny"
    policy=$(setup_policy $test_bucket_name $client $profile)
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The stdout should include ""
      The status should be success
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The stdout should include ""
      The status should be success
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    aws --profile $profile s3api delete-bucket-policy --bucket "$test_bucket_name" > /dev/null
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

Describe 'Validate Alternative to object-lock:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:DeleteObject"'
    principal="*"
    resource="$test_bucket_name/$file1_name"
    effect="Deny"
    policy=$(setup_policy $test_bucket_name $client $profile)
    wait_command bucket-exists $profile "$test_bucket_name"
    aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy" > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile-second s3 rm s3://$test_bucket_name/$file1_name
      The stderr should include "AccessDenied"
      The status should be failure
      ;;
    "rclone")
      When run rclone delete $profile-second:$test_bucket_name/$file1_name
      The stderr should include "AccessDenied"
      The status should be failure
      ;;
    "mgc")
      mgc workspace set $profile-second
      When run bash ./spec/retry_command.sh "mgc os objects delete $test_bucket_name/$file1_name --no-confirm" "AccessDenied"
      The stdout should include "AccessDenied"
      The status should be failure
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    aws --profile $profile s3api delete-bucket-policy --bucket "$test_bucket_name" > /dev/null
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
    #wait_command bucket-not-exists "$profile" "$test_bucket_name"
  End
End

###
# Malformed policy
###
Describe 'Put bucket policy without Resources:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    principal="*"
    resource="$test_bucket_name-invalid-$client/*"
    effect="Allow"
    first_policy=$(setup_policy $test_bucket_name $client $profile)
    policy=$(policy-without "$first_policy" "Resource")
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
  End
End
Describe 'Put bucket policy without Action:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    principal="*"
    resource="$test_bucket_name-invalid-$client/*"
    effect="Allow"
    first_policy=$(setup_policy $test_bucket_name $client $profile)
    policy=$(policy-without "$first_policy" "Action")
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
  End
End
Describe 'Put bucket policy without Principal:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    principal="*"
    resource="$test_bucket_name-invalid-$client/*"
    effect="Allow"
    first_policy=$(setup_policy $test_bucket_name $client $profile)
    policy=$(policy-without "$first_policy" "Principal")
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
  End
End
Describe 'Put bucket policy without Effect:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    principal="*"
    resource="$test_bucket_name-invalid-$client/*"
    effect="Allow"
    first_policy=$(setup_policy $test_bucket_name $client $profile)
    policy=$(policy-without "$first_policy" "Effect")
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
  End
End
Describe 'Put bucket policy with no Statement:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    principal="*"
    resource="$test_bucket_name-invalid-$client/*"
    effect="Allow"
    policy=$(setup_policy $test_bucket_name $client $profile | jq 'del(.Statement)')
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
  End
End

###
# Invalid fields
###
Describe 'Put bucket policy with Resource outside bucket:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    principal="*"
    resource="$test_bucket_name-invalid-$client/*"
    effect="Allow"
    policy=$(setup_policy $test_bucket_name $client $profile)
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
  End
End
Describe 'Put bucket policy with empty Resource:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    principal="*"
    resource="$test_bucket_name-invalid-$client/*"
    effect="Allow"
    first_policy=$(setup_policy $test_bucket_name $client $profile)
    policy=$(policy-with-empty "$first_policy" "Resource")
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "flag \"--policy=null\" error: invalid \"/0\": json: cannot unmarshal array into Go value of type map[string]interface {}"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
  End
End
Describe 'Put bucket policy with empty Action:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    principal="*"
    resource="$test_bucket_name-invalid-$client/*"
    effect="Allow"
    first_policy=$(setup_policy $test_bucket_name $client $profile)
    policy=$(policy-with-empty "$first_policy" "Action")
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "flag \"--policy=null\" error: invalid \"/0\": json: cannot unmarshal array into Go value of type map[string]interface {}"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
  End
End
Describe 'Put bucket policy with empty Principal:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    principal="*"
    resource="$test_bucket_name-invalid-$client/*"
    effect="Allow"
    first_policy=$(setup_policy $test_bucket_name $client $profile)
    policy=$(policy-with-empty "$first_policy" "Principal")
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "flag \"--policy=null\" error: invalid \"/0\": json: cannot unmarshal string into Go value of type map[string]interface {}"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
  End
End
Describe 'Put bucket policy with empty Effect:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    principal="*"
    resource="$test_bucket_name-invalid-$client/*"
    effect="Allow"
    first_policy=$(setup_policy $test_bucket_name $client $profile)
    policy=$(policy-with-empty "$first_policy" "Effect")
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "flag \"--policy=null\" error: invalid \"/0\": json: cannot unmarshal string into Go value of type map[string]interface {}"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
  End
End
Describe 'Put bucket policy with empty Statement:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    #policy vars
    action='"s3:GetObject"'
    principal="*"
    resource="$test_bucket_name-invalid-$client/*"
    effect="Allow"
    policy=$(setup_policy $test_bucket_name $client $profile | jq '.Statement |= []')
    wait_command bucket-exists $profile "$test_bucket_name"
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
      When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    "rclone")
      Skip "No such operation in client $client"
      ;;
    "mgc")
      echo mgc workspace set $profile > /dev/null
      When run mgc os buckets policy set --dst $test_bucket_name --policy "$policy"
      The status should be failure
      The stderr should include "MalformedPolicy"
      ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
  End
End

###
# Cross access
###
Describe 'Access other buckets - User 1 gives access to user 3 and user 2 is locked:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"

    # Check if other profiles exist, we need 3 for this test to work
    user2id=$(aws s3api --profile $profile-second list-buckets | jq -r '.Owner.ID')
    if $(is_variable_null "$user2id"); then return; fi # ! SKIP DOES NOT SKIP
    user3id=$(aws s3api --profile $profile-third list-buckets | jq -r '.Owner.ID')
    if $(is_variable_null "$user3id"); then return; fi # ! SKIP DOES NOT SKIP
    #policy vars
    action='"s3:ListBucket","s3:GetObject"'
    principal="$user3id"
    resource=("$test_bucket_name" "$test_bucket_name/*")
    effect="Allow"
    policy=$(setup_policy $test_bucket_name $client $profile)
    wait_command bucket-exists $profile "$test_bucket_name"
    aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy" > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
        When run aws --profile $profile-second s3api list-objects-v2 --bucket "$test_bucket_name"
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
    "rclone")
        When run rclone ls $profile-second:$test_bucket_name
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
    "mgc")
        mgc workspace set $profile-second
        When run bash ./spec/retry_command.sh "mgc os objects list --dst "$test_bucket_name"" "AccessDenied"
        The stdout should include "AccessDenied"
        The status should be failure
        ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    aws --profile $profile s3api delete-bucket-policy --bucket "$test_bucket_name" > /dev/null
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
  End
End

Describe 'Access other buckets - User 1 gives read access to user 2 and user 2 cannot do other operations:' category:"BucketPolicy" category:"quick"
  local ready=false
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  BeforeAll 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2: setup policy" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"

    # Check if other profiles exist
    user2id=$(aws s3api --profile $profile-second list-buckets | jq -r '.Owner.ID')
    if $(is_variable_null "$user2id"); then
      return # ! SKIP DOES NOT SKIP
    else
      ready=true
    fi

    #policy vars
    action='"s3:ListBucket","s3:GetObject"'
    principal="$user2id"
    resource=("$test_bucket_name" "$test_bucket_name/*")
    effect="Allow"
    policy=$(setup_policy $test_bucket_name $client $profile)

    wait_command bucket-exists $profile "$test_bucket_name"
    When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy" > /dev/null
    The status should be success
    echo "Created policy in bucket $bucket_name" > /dev/null
  End
  Example "on profile $1 using client $2: user tries to read" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    [ ! $ready ] && Skip "Test was not correctly setup" && return
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
        When run bash ./spec/retry_command.sh "aws --profile $profile-second s3api list-objects-v2 --bucket $test_bucket_name"
        The stdout should include $file1_name
        The status should be success
        ;;
    "rclone")
        When run bash ./spec/retry_command.sh "rclone ls $profile-second:$test_bucket_name"
        The stdout should include $file1_name
        The status should be success
        ;;
    "mgc")
        mgc workspace set $profile-second
        When run bash ./spec/retry_command.sh " mgc os objects list --dst $test_bucket_name"
        The stdout should include $file1_name
        The status should be success
        ;;
    esac
  End
  Example "on profile $1 using client $2: user tries to write" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    [ ! $ready ] && Skip "Test was not correctly setup" && return
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
        When run  aws --profile $profile-second s3api put-object --bucket $test_bucket_name --key $file1_name-copy --body "$(pwd)/$file1_name"
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
    "rclone")
        When run rclone copy "$(pwd)/$file1_name" $profile-second:$test_bucket_name/$file1_name-copy
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
    "mgc")
        mgc workspace set $profile-second
        When run bash ./spec/retry_command.sh "mgc os objects upload --dst $test_bucket_name/$file1_name-copy --src $file1_name" "AccessDenied"
        The stdout should include "AccessDenied"
        The status should be failure
        ;;
    esac
  End
  Example "on profile $1 using client $2: user tries to delete" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    [ ! $ready ] && Skip "Test was not correctly setup" && return
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
        When run aws --profile $profile-second s3api delete-object --bucket $test_bucket_name --key $file1_name
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
    "rclone")
        When run rclone delete $profile-second:$test_bucket_name/$file1_name
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
    "mgc")
        mgc workspace set $profile-second
        When run bash ./spec/retry_command.sh "mgc os objects delete $test_bucket_name/$file1_name --no-confirm" "AccessDenied"
        The stdout should include "AccessDenied"
        The status should be failure
        ;;
    esac
  End
  Example "on profile $1 using client $2: user tries to remove policy" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    [ ! $ready ] && Skip "Test was not correctly setup" && return
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
        When run aws --profile $profile-second s3api delete-bucket-policy --bucket $test_bucket_name > /dev/null
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
    "rclone")
        Skip "No such operation in client $client"
        ;;
    "mgc")
        mgc workspace set $profile-second
        When run bash ./spec/retry_command.sh "mgc os buckets policy delete --dst $test_bucket_name" "AccessDenied"
        The stdout should include "AccessDenied"
        The status should be failure
        ;;
    esac
  End
  Example "on profile $1 using client $2: cleanup" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    [ ! $ready ] && Skip "Test was not correctly setup" && return
    cleanup() {
    wait_command bucket-exists $profile "$test_bucket_name" \
      && aws --profile $profile s3api delete-bucket-policy --bucket "$test_bucket_name" > /dev/null \
      && bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null \
      || true
    }
    When run cleanup
    The status should be success
    The stdout should include "last wait bucket-exists for profile $profile"
  End
End

Describe 'Access other buckets - User 1 gives write access to user 2 and user 2 cannot do other operations:' category:"BucketPolicy" category:"quick"
  setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  BeforeAll 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2: setup policy" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"

    # Check if other profiles exist
    user2id=$(aws s3api --profile $profile-second list-buckets | jq -r '.Owner.ID')
    if $(is_variable_null "$user2id"); then
      return # ! SKIP DOES NOT SKIP
    else
      ready=true
    fi

    #policy vars
    action='"s3:PutObject","s3:GetObject"'
    principal="$user2id"
    resource=("$test_bucket_name" "$test_bucket_name/*")
    effect="Allow"
    policy=$(setup_policy $test_bucket_name $client $profile)
    wait_command bucket-exists $profile "$test_bucket_name"
    When run aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy" > /dev/null
    The status should be success
    echo "Created policy in bucket $bucket_name" > /dev/null
  End

  Example "on profile $1 using client $2: user tries to read" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    # [ ! $ready ] && Skip "Test was not correctly setup" && return
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
        When run aws --profile $profile-second s3api list-objects-v2 --bucket $test_bucket_name
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
    "rclone")
        When run rclone ls $profile-second:$test_bucket_name
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
    "mgc")
        mgc workspace set $profile-second
        When run mgc os objects list $test_bucket_name
        The stderr should include "403"
        The stdout should include ""
        The status should be failure
        ;;
    esac
  End
  Example "on profile $1 using client $2: user tries to write" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    # [ ! $ready ] && Skip "Test was not correctly setup" && return
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
        When run bash ./spec/retry_command.sh "aws --profile $profile-second s3api put-object --bucket $test_bucket_name --key $file1_name-copy --body "$(pwd)/$file1_name""
        The stdout should include ""
        The status should be success
        ;;
    "rclone")
        # When run rclone copy "$(pwd)/$file1_name" $profile-second://$test_bucket_name/$file_name-copy
        # The stdout should include ""
        # The status should be success
        Skip "Skipped test to $client"
        ;;
    "mgc")
        mgc workspace set $profile-second
        When run bash ./spec/retry_command.sh "mgc os objects upload --dst $test_bucket_name/$file1_name-copy --src $file1_name"
        The stdout should include $file1_name
        The status should be success
        ;;
    esac
  End
  Example "on profile $1 using client $2: user tries to delete" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    # [ ! $ready ] && Skip "Test was not correctly setup" && return
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
        When run aws --profile $profile-second s3api delete-object --bucket $test_bucket_name --key $file1_name
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
    "rclone")
        When run rclone delete $profile-second:$test_bucket_name/$file1_name
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
    "mgc")
        mgc workspace set $profile-second
        When run bash ./spec/retry_command.sh "mgc os objects delete $test_bucket_name/$file1_name --no-confirm --debug" "AccessDenied"
        The stdout should include "AccessDenied"
        The status should be failure
        ;;
    esac
  End
  Example "on profile $1 using client $2: user tries to remove policy" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    # [ ! $ready ] && Skip "Test was not correctly setup" && return
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
        When run aws --profile $profile-second s3api delete-bucket-policy --bucket $test_bucket_name > /dev/null
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
    "rclone")
        Skip "No such operation in client $client"
        ;;
    "mgc")
        mgc workspace set $profile-second
        When run bash ./spec/retry_command.sh "mgc os buckets policy delete --dst $test_bucket_name" "AccessDenied"
        The stdout should include "AccessDenied"
        The status should be failure
        ;;
    esac
  End
  Example "on profile $1 using client $2: cleanup" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    # [ ! $ready ] && Skip "Test was not correctly setup" && return
    cleanup() {
    wait_command bucket-exists $profile "$test_bucket_name" \
      && aws --profile $profile s3api delete-bucket-policy --bucket "$test_bucket_name" > /dev/null \
      && bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null \
      || true
    }
    When run cleanup
    The status should be success
    The stdout should include ""
  End
End

Describe 'Owner denies all access but can still change policy:' category:"BucketPolicy" category:"quick"
    setup(){
    bucket_name="test-091-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "on profile $1 using client $2" id:"091"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"

    # Check if other profiles exist, we need 3 for this test to work
    user2id=$(aws s3api --profile $profile-second list-buckets | jq -r '.Owner.ID')
    if $(is_variable_null "$user2id"); then return; fi # ! SKIP DOES NOT SKIP
    user3id=$(aws s3api --profile $profile-third list-buckets | jq -r '.Owner.ID')
    if $(is_variable_null "$user3id"); then return; fi # ! SKIP DOES NOT SKIP

    #policy vars
    # action='"s3:DeleteBucketPolicy", "s3:GetBucketAcl", "s3:GetBucketPolicy", "s3:GetBucketPolicyStatus",
    # "s3:GetBucketVersioning", "s3:ListBucket", "s3:ListBucketMultipartUploads", "s3:ListBucketVersions",
    # "s3:PutBucketAcl", "s3:PutBucketPolicy", "s3:PutBucketVersioning", "s3:AbortMultipartUpload", "s3:DeleteObject",
    # "s3:GetObject", "s3:GetObjectAcl", "s3:ListMultipartUploadParts", "s3:PutObject", "s3:PutObjectAcl"'
    action='"s3:*"'
    principal="*"
    resource=("$test_bucket_name" "$test_bucket_name/*")
    effect="Deny"
    policy=$(setup_policy $test_bucket_name $client $profile)
    wait_command bucket-exists $profile "$test_bucket_name"
    aws --profile $profile s3api put-bucket-policy --bucket $test_bucket_name --policy "$policy" > /dev/null
    case "$client" in
    "aws-s3api" | "aws" | "aws-s3")
        When run aws --profile $profile s3api delete-bucket-policy --bucket "$test_bucket_name"
        The status should be success
        The stdout should include ""
        ;;
    "rclone")
        Skip "No such operation in client $client"
        ;;
    "mgc")
        mgc workspace set $profile
        When run mgc os buckets policy delete --dst "$test_bucket_name"
        The status should be success
        The stdout should include ""
        ;;
    esac
    wait_command bucket-exists "$profile" "$test_bucket_name"
    aws --profile $profile s3api delete-bucket-policy --bucket "$test_bucket_name" > /dev/null
    bash ./spec/retry_command.sh "rclone purge $profile:$test_bucket_name" > /dev/null
  End
End
