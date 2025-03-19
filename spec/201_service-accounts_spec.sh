# Service account tests
# =====================
#
# Service accounts in the context of the following tests are accounts created with no permissions,
# they cannot list buckets and cannot create new buckets. All read and write access of object by
# those service accounts needs to be explicited as an "Allow" rule in a Bucket Policy Statement.
# =====================

# import functions: check_missing_profile wait_for_policy_put and wait_for_policy_delete
Include ./spec/201_utils.sh

Describe "Service Accounts: " category:"ServiceAccounts"  id:"201"
  setup(){
    bucket_name="test-201-$(date +%s)"
    key_name="key_1"
  }
  BeforeAll 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Describe "Should NOT be able to" category:"ServiceAccounts"  id:"202"
    Example "list buckets."
      profile=$1
      sa_profile=$profile-sa
      client=$2

      Skip if "Profile "$sa_profile" is missing" check_missing_profile "$sa_profile"
      if $(check_missing_profile "$profile"); then return; fi # ! SKIP DOES NOT SKIP

      case "$client" in
      "aws-s3api" | "aws" | "aws-s3")
        When run aws --profile $sa_profile s3api list-buckets
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
      "rclone")
        When run rclone lsd $sa_profile:
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
      "mgc")
        # mgc 0.25.0 uses workspace set to change profiles (not set profile as 0.21)
        mgc workspace set $sa_profile > /dev/null
        When run mgc object-storage buckets list --raw
        The status should be failure
        The stderr should include "AccessDenied"
        ;;
      esac
    End
    Example "create bucket."
      profile=$1
      sa_profile=$profile-sa
      client=$2

      Skip if "Profile "$sa_profile" is missing" check_missing_profile "$sa_profile"
      if $(check_missing_profile "$profile"); then return; fi # ! SKIP DOES NOT SKIP

      case "$client" in
      "aws-s3api" | "aws" | "aws-s3")
        When run aws --profile $sa_profile s3api create-bucket --bucket $bucket_name
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
      "rclone")
        When run rclone mkdir $sa_profile:$bucket_name
        The stderr should include "AccessDenied"
        The status should be failure
        ;;
      "mgc")
        # mgc 0.25.0 uses workspace set to change profiles (not set profile as 0.21)
        mgc workspace set $sa_profile > /dev/null
        When run mgc object-storage buckets create --bucket $bucket_name --raw
        The status should be failure
        The stderr should include "AccessDenied"
        ;;
      esac
    End
  End


  Describe "Should be able, with bucket policy, to" category:"ServiceAccounts" id:"203"

    Describe "setup"
      Example "test bucket"
        profile=$1
        sa_profile=$profile-sa
        client=$2
        test_bucket_name="$bucket_name-$client-$profile"

        Skip if "Profile "$sa_profile" is missing" check_missing_profile "$sa_profile"
        if $(check_missing_profile "$profile"); then return; fi # ! SKIP DOES NOT SKIP

        When run aws s3 mb s3://$test_bucket_name --profile $profile
        The status should be success
        The stdout should include "$test_bucket_name"
      End
      Example "put test object"
        profile=$1
        sa_profile=$profile-sa
        client=$2
        file="LICENSE"
        test_bucket_name="$bucket_name-$client-$profile"

        Skip if "Profile "$sa_profile" is missing" check_missing_profile "$sa_profile"
        if $(check_missing_profile "$profile"); then return; fi # ! SKIP DOES NOT SKIP

        When run aws s3api put-object --bucket $test_bucket_name --key $key_name --body $file --profile $profile
        The status should be success
        The stdout should include "ETag"
      End
    End

    Describe "tests"
      Example "put bucket policy (s3:GetObject)"
        profile=$1
        sa_profile=$profile-sa
        client=$2
        test_bucket_name="$bucket_name-$client-$profile"

        Skip if "Profile "$sa_profile" is missing" check_missing_profile "$sa_profile"
        if $(check_missing_profile "$profile"); then return; fi # ! SKIP DOES NOT SKIP

        bucket_policy_template='{
            "Version": "2012-10-17",
            "Statement": []
        }'
        statement_template='{
            "Principal": {},
            "Effect": "",
            "Action": [],
            "Resource": []
        }'

        # TODO: come up with a way to get the sa key email instead of using it hardcoded
        # sa de pessoa fisica
        # sa_tenant_id="a814fac6-02c0-4218-84b9-509ed782fc92"
        # sa_key_email="sa5@IDM-Q2QZ-LI1-5BFS.sa.idmagalu.com"
        # sa_policy_principal="$sa_tenant_id:sa/$sa_key_email"
        # sa de organization
        sa_tenant_id="8d475459-5f6a-4892-b149-d7e4de0d764d"
        sa_key_email="sa3@HDN-2582.sa.idmagalu.com"
        sa_policy_principal="$sa_tenant_id:sa/$sa_key_email"

        principal_1="$sa_policy_principal"
        statement_1=$(jq \
          --arg effect "Allow" \
          --arg action_1 "s3:GetObject" \
          --arg principal_1 "$principal_1" \
          --arg resource_1 "$test_bucket_name/$key_name" \
        '.Effect = $effect | .Principal = { MGC: $principal_1 } | .Action = [$action_1] | .Resource = [$resource_1]' <<< "$statement_template"
        )

        policy=$( jq \
          --argjson statement_1 "$statement_1" \
          '.Statement = [$statement_1]' <<< "$bucket_policy_template")

        # debug
        echo "$policy" | jq .

        case "$client" in
        "aws-s3api" | "aws" | "aws-s3")
          When run aws s3api put-bucket-policy --profile $profile --bucket $test_bucket_name --policy "$policy"
          The status should be success
          wait_for_policy_put "$test_bucket_name" "$profile"
          ;;
        "rclone")
          ;;
        "mgc")
          ;;
        esac
      End
      Example "get object"
        profile=$1
        sa_profile="$1-sa"
        second_profile="$1-second"
        client=$2
        local_file="/tmp/downloaded_key_1"
        test_bucket_name="$bucket_name-$client-$profile"

        Skip if "Profile "$sa_profile" is missing" check_missing_profile "$sa_profile"
        if $(check_missing_profile "$profile"); then return; fi # ! SKIP DOES NOT SKIP

        case "$client" in
        "aws-s3api" | "aws" | "aws-s3")
          When run aws s3api get-object --profile $sa_profile --bucket $test_bucket_name --key $key_name $local_file
          The status should be success
          The stdout should include "ETag"
          ;;
        "rclone")
          ;;
        "mgc")
          ;;
        esac
      End
      Example "but not put object"
        profile=$1
        sa_profile="$1-sa"
        client=$2
        file="LICENSE"
        test_bucket_name="$bucket_name-$client-$profile"

        Skip if "Profile "$sa_profile" is missing" check_missing_profile "$sa_profile"
        if $(check_missing_profile "$profile"); then return; fi # ! SKIP DOES NOT SKIP

        case "$client" in
        "aws-s3api" | "aws" | "aws-s3")
          When run aws s3api put-object --profile $sa_profile --bucket $test_bucket_name --key $key_name --body $file
          The status should be failure
          The stderr should include "AccessDenied"
          ;;
        "rclone")
          ;;
        "mgc")
          ;;
        esac
      End
    End

    Describe "teardown" id:"203"
      Example "bucket policy"
        profile=$1
        sa_profile=$profile-sa
        client=$2
        test_bucket_name="$bucket_name-$client-$profile"

        Skip if "Profile "$sa_profile" is missing" check_missing_profile "$sa_profile"
        if $(check_missing_profile "$profile"); then return; fi # ! SKIP DOES NOT SKIP

        case "$client" in
        "aws-s3api" | "aws" | "aws-s3")
          When run aws s3api delete-bucket-policy --profile $profile --bucket $test_bucket_name
          The status should be success
          wait_for_policy_delete "$test_bucket_name" "$profile"
          ;;
        "rclone")
          ;;
        "mgc")
          ;;
        esac
      End
      Example "test bucket"
        profile=$1
        sa_profile=$profile-sa
        client=$2
        test_bucket_name="$bucket_name-$client-$profile"

        Skip if "Profile "$sa_profile" is missing" check_missing_profile "$sa_profile"
        if $(check_missing_profile "$profile"); then return; fi # ! SKIP DOES NOT SKIP

        When run rclone purge $profile:$test_bucket_name > /dev/null
        The status should be success
      End
    End
  End
End
