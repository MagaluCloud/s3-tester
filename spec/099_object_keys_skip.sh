# RUN WITH
# shellspec --env PROFILES=FIXME spec/099_object_keys_spec.sh


bucket_name="s3-tester-$(openssl rand -hex 10 | tr -dc 'a-z0-9' | head -c 10)"
for i in $PROFILES; do
  # Create sample bucket to validate listing
  aws --profile "$i" s3api create-bucket --bucket "$bucket_name"> /dev/null
done

delete_buckets() {
  for i in $PROFILES; do
    aws --profile "$i" s3 rb --force "s3://$bucket_name" > /dev/null
  done
}

%const NAMES: "\
  foo  foo/ foo// foo/bin foo/////bin \
  . ./ ././. \
  .. ../ ../../.. \
  / % | ! @ # $ % ^ &  ( ) { } [ ] 🚩 \
  "
# echo "$NAMES"
# for k in $NAMES; do
#   echo  "$k"
# done

Describe 'Object keys' category:"ObjectManagement"  category:"quick"
  Parameters:dynamic
    for i in $PROFILES; do
      for k in $NAMES; do
        %data "$i" "$k"
      done
      %data "$i" "com espaço" # Esse não dá para colocar em $NAMES por ter espaço
    done
  End

  AfterAll delete_buckets

  Example "on profile $i bucket $bucket_name key \"$2\""
    When run aws --profile "$i" s3api put-object --bucket "$bucket_name" --key "$2"
    The output should include "ETag"
    The status should be success
  End
End


