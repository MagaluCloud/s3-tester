#!/bin/bash
SCRIPT_PATH="$( cd "$( echo "${BASH_SOURCE[0]%/*}" )" && pwd )"

# split arguments before and after double dash
source "$SCRIPT_PATH/lib/doubledashsplit.sh"

# arguments
source "$SCRIPT_PATH/../vendor/yaacov/argparse.sh"
define_arg "clients" "aws-s3api,aws-s3,rclone,mgc" "S3 clients that will perform the tests" "string" "false"
define_arg "profiles" "" "Profiles to use in the tests, must have the same name on all clients" "string" "true"
define_arg "tests" "" "A list of individual tests to perform" "string" "false"
define_arg "categories" "" "(optional) A list of test groups to include" "string" "false"
define_arg "tags" "" "(optional) A list of shellspec tags to include" "string" "false"
set_description "Run tests on multiple S3 providers using multiple S3 clients.\nUse -- [shellspec args...] in the end to pass more arguments to shellspec."

check_for_help $args_after_double_dash
parse_args $args_before_double_dash

profiles_to_clean=$profiles

# convert comma separated lists to space separated
clients="${clients//,/ }"
profiles="${profiles//,/ }"
tests="${tests//,/ }"
categories="${categories//,/ }"
tags="${tags//,/ }"

# convert test numbers to test "id" tags
tag_args=""
for num in $tests; do
    padded_num=$(printf "%03d" $num)  # Padding each number with zeroes to three digits
    tag_args+=" --tag id:${padded_num}"
done
for category in $categories; do
    tag_args+=" --tag category:${category}"
done
for tag in $tags; do
    tag_args+=" --tag ${tag}"
done

# print the tools shasum
shasum `which mgc` `which aws` `which rclone`

# benchmark test uses other envs, this sets a default value
SIZES=${SIZES:-0}
SIZE=${SIZE:-0}
QUANTITY=${QUANTITY:-0}
DATE=${DATE:-0}
TIMES=${TIMES:-0}
WORKERS=${WORKERS:-0}
benchmark_envs='--env SIZES="$SIZES" --env SIZE="$SIZE" --env QUANTITY="$QUANTITY" --env DATE="$DATE" --env TIMES="$TIMES" --env WORKERS="$WORKERS"'

# run the tests
shellspec -c "$SCRIPT_PATH/../spec" --env CLIENTS="$clients" --env PROFILES="$profiles" -s bash $tag_args $args_after_double_dash $benchmark_envs
