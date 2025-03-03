#!/bin/bash
SCRIPT_PATH="$( cd "$( echo "${BASH_SOURCE[0]%/*}" )" && pwd )"

# split arguments before and after double dash
source "$SCRIPT_PATH/lib/doubledashsplit.sh"

# arguments
source "$SCRIPT_PATH/../vendor/yaacov/argparse.sh"
define_arg "clients" "aws-s3api,aws-s3,rclone,mgc" "S3 clients that will perform the tests" "string" "false"
define_arg "profiles" "" "Profiles to use in the tests, must have the same name on all clients" "string" "true"
define_arg "size" "" "Individual size on benchmark to perform" "string" "false"
define_arg "quantity" "" "A list of individual quantity on benchmark to perform" "string" "false"
define_arg "workers" "" "A number of workers to perform more faster uploads/downloads" "string" "false"
set_description "Run tests on multiple S3 providers using multiple S3 clients.\nUse -- [shellspec args...] in the end to pass more arguments to shellspec."

check_for_help $args_after_double_dash
parse_args $args_before_double_dash

profiles_to_clean=$profiles

# convert comma separated lists to space separated
clients="${clients//,/ }"
profiles="${profiles//,/ }"
size=${size:-"1"}  # Define um valor padrão para size
size="${size//,/ }"
quantity="${quantity//,/ }"
workers="${workers//,/ }"

# convert test numbers to test "id" tags
tag_args=""
for num in '194'; do
    padded_num=$(printf "%03d" $num)  # Padding each number with zeroes to three digits
    tag_args+=" --tag id:${padded_num}"
done

# print the tools shasum
shasum `which mgc` `which aws` `which rclone`

# benchmark test uses other envs, this sets a default value
SIZES=${SIZES:-0}
DATE=${DATE:-0}
TIMES=${TIMES:-0}
benchmark_envs='--env SIZES="$SIZES" --env DATE="$DATE" --env TIMES="$TIMES" '

# run the tests
shellspec -c "$SCRIPT_PATH/../spec" --env CLIENTS="$clients" --env PROFILES="$profiles" --env QUANTITY="$quantity" --env WORKERS="$workers" --env SIZE="$size" -s bash $tag_args $args_after_double_dash  $benchmark_envs
