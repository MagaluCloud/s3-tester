validate_key_in_objects() {
  command=$1
  profile=$2
  bucket_name=$3
  object_key=$4
  required_successes=${5:-2} # numero de sucessos necessários para validar o teste
  max_retries=1000
  retry_interval=0
  success_count=0

  for ((i=1; i<=max_retries; i++))
  do
    echo "Attempt $i: Checking for objects in bucket '$bucket_name' using command '$command'..."

    case $command in
      "list-objects")
        objects=$(aws --profile $profile s3api list-objects-v2 --bucket $bucket_name --query "Contents[].Key" --output text 2>/dev/null)
        if echo "$objects" | grep -q "$object_key"; then
          success_count=$((success_count + 1))
          echo "Key '$object_key' found in bucket '$bucket_name'. Success count: $success_count/$required_successes"
          if [ $success_count -ge $required_successes ]; then
            return 0 # Retorna sucesso (objeto encontrado) e sai da função
          fi
        else
          echo "Key '$object_key' not found in bucket '$bucket_name'."
        fi
        ;;

      "get-object")
        aws --profile $profile s3api get-object --bucket $bucket_name --key "$object_key" /dev/null > /dev/null 2>&1 &
        wait $!
        if [ $? -eq 0 ]; then
          success_count=$((success_count + 1))
          echo "Key '$object_key' exists in bucket '$bucket_name'. Success count: $success_count/$required_successes"
          if [ $success_count -ge $required_successes ]; then
            return 0 # Retorna sucesso e sai da função
          fi
        fi
        ;;

      "head-object")
        aws --profile $profile s3api head-object --bucket $bucket_name --key "$object_key" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          success_count=$((success_count + 1))
          echo "Key '$object_key' exists in bucket '$bucket_name'. Success count: $success_count/$required_successes"
          if [ $success_count -ge $required_successes ]; then
            return 0 # Retorna sucesso e sai da função
          fi
        fi
        ;;

      *)
        echo "Invalid command: $command. Use 'list-objects', 'get-object', or 'head-object'."
        return -1
        ;;
    esac

    sleep $retry_interval
  done

  if [ -z "$object_key" ]; then
    echo "Max retries reached. Bucket '$bucket_name' still contains objects."
    return 0 # Retorna falha (objetos ainda existem) após o número máximo de tentativas
  else
    echo "Max retries reached. Key '$object_key' not found in bucket '$bucket_name'."
    return 1 # Retorna falha (objeto não encontrado) após o número máximo de tentativas
  fi
}

create_temp_objects() {
  quantity=$1
  size=$2
  dir_name="temp-report-${quantity}-${size}"

  if [ ! -d "$dir_name" ]; then
    mkdir "$dir_name" > /dev/null
    echo "Diretório '$dir_name' criado." > /dev/null
  else
    echo "Diretório '$dir_name' já existe." > /dev/null
  fi

  for i in $(seq 1 $quantity); do
    fallocate -l "${size}k" "./$dir_name/arquivo_$i.txt"
  done
}

mkdir -p ./report
touch ./report/report-inconsistencies.csv
echo "quantity,size,workers,command,profile,client,time" > ./report/report-inconsistencies.csv
# Testes com 1 objeto sem paralelismo

Describe '1, get-object'
  setup(){
    bucket_name="test-194-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "bucket exists on profile $1 using client $2" id:"194"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null

    case "$client" in
      "aws-s3api" | "aws" | "aws-s3" | "rclone" | "mgc")
        start_time=$(date +%s%3N)
        validate_key_in_objects "get-object" "$profile" "$test_bucket_name" "$file1_name"
        if [ $? -eq 0 ]; then
          echo "Key '$file1_name' found in bucket '$test_bucket_name'."
        else
          echo "Key '$file1_name' not found in bucket '$test_bucket_name'."
        fi
        end_time=$(date +%s%3N)
        object_exists_time=$((end_time - start_time))
        ;;
    esac
    echo "1,1,1,get-object,$profile,$client,$object_exists_time" >> ./report/report-inconsistencies.csv
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

Describe '1, list-objects'
  setup(){
    bucket_name="test-194-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "bucket exists on profile $1 using client $2" id:"194"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null

    case "$client" in
      "aws-s3api" | "aws" | "aws-s3" | "rclone" | "mgc")
        start_time=$(date +%s%3N)
        validate_key_in_objects "list-objects" "$profile" "$test_bucket_name" "$file1_name"
        end_time=$(date +%s%3N)
        object_exists_time=$((end_time - start_time))
        ;;
    esac
    echo "1,1,1,list-objects,$profile,$client,$object_exists_time" >> ./report/report-inconsistencies.csv
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

Describe '1, head-object'
  setup(){
    bucket_name="test-194-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "bucket exists on profile $1 using client $2" id:"194"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null

    case "$client" in
      "aws-s3api" | "aws" | "aws-s3" | "rclone" | "mgc")
        start_time=$(date +%s%3N)
        validate_key_in_objects "head-object" "$profile" "$test_bucket_name" "$file1_name"
        if [ $? -eq 0 ]; then
          echo "Key '$file1_name' found in bucket '$test_bucket_name'."
        else
          echo "Key '$file1_name' not found in bucket '$test_bucket_name'."
        fi
        end_time=$(date +%s%3N)
        object_exists_time=$((end_time - start_time))
        ;;
    esac
    echo "1,1,1,head-object,$profile,$client,$object_exists_time" >> ./report/report-inconsistencies.csv
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

# Testes com parametros de quantidade, tamanho e workers

Describe 'Parameter, get-object'
  setup(){
    bucket_name="test-get-object-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
    $QUANTITY
    $WORKERS
    $SIZE
  End
  Example "bucket exists on profile $1 using client $2 with $3 objects" id:"194"
    profile=$1
    client=$2
    quantity=$3
    workers=$4
    size=$5
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null

    create_temp_objects $quantity $size
    mgc workspace set $profile > /dev/null
    mgc object-storage objects upload-dir ./temp-report-${quantity}-${size} $test_bucket_name/${quantity}-${size}/ --workers $workers

    # Validar o último objeto usando get-object
    last_object_name="${quantity}-${size}/arquivo_$quantity.txt"
    start_time=$(date +%s%3N)
    validate_key_in_objects "get-object" "$profile" "$test_bucket_name" "$last_object_name"
    if [ $? -eq 0 ]; then
      echo "Key '$last_object_name' found in bucket '$test_bucket_name' using get-object."
    else
      echo "Key '$last_object_name' not found in bucket '$test_bucket_name' using get-object."
    fi
    end_time=$(date +%s%3N)
    get_object_time=$((end_time - start_time))

    # Salvar resultados no CSV
    echo "$quantity,$size,$workers,get-object,$profile,$client,$get_object_time" >> ./report/report-inconsistencies.csv

    # Limpar o bucket
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

Describe 'Parameter, list-objects'
  setup(){
    bucket_name="test-list-objects-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
    $QUANTITY
    $WORKERS
    $SIZE
  End
  Example "bucket exists on profile $1 using client $2 with $3 objects" id:"194"
    profile=$1
    client=$2
    quantity=$3
    workers=$4
    size=$5
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null

    create_temp_objects $quantity $size
    mgc workspace set $profile > /dev/null
    mgc object-storage objects upload-dir ./temp-report-${quantity}-${size} $test_bucket_name/${quantity}-${size}/ --workers $workers

    # Validar o último objeto usando list-objects
    last_object_name="${quantity}-${size}/arquivo_$quantity.txt"
    start_time=$(date +%s%3N)
    validate_key_in_objects "list-objects" "$profile" "$test_bucket_name" "$last_object_name"
    if [ $? -eq 0 ]; then
      echo "Key '$last_object_name' found in bucket '$test_bucket_name' using list-objects."
    else
      echo "Key '$last_object_name' not found in bucket '$test_bucket_name' using list-objects."
    fi
    end_time=$(date +%s%3N)
    list_objects_time=$((end_time - start_time))

    # Salvar resultados no CSV
    echo "$quantity,$size,$workers,list-objects,$profile,$client,$list_objects_time" >> ./report/report-inconsistencies.csv

    # Limpar o bucket
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

Describe 'Parameter, head-object'
  setup(){
    bucket_name="test-head-object-$(date +%s)-$RANDOM"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
    $QUANTITY
    $WORKERS
    $SIZE
  End
  Example "bucket exists on profile $1 using client $2 with $3 objects" id:"194"
    profile=$1
    client=$2
    quantity=$3
    workers=$4
    size=$5
    test_bucket_name="$bucket_name-$client-$profile"

    # Criar o bucket
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    if [ $? -ne 0 ]; then
      echo "Failed to create bucket '$test_bucket_name'."
      exit 1
    fi

    # Criar objetos temporários
    create_temp_objects $quantity $size
    if [ ! -d "./temp-report-${quantity}-${size}" ]; then
      echo "Directory './temp-report-${quantity}-${size}' does not exist."
      exit 1
    fi

    # Fazer upload dos objetos
    mgc workspace set $profile > /dev/null
    mgc object-storage objects upload-dir ./temp-report-${quantity}-${size} $test_bucket_name/${quantity}-${size}/ --workers $workers
    if [ $? -ne 0 ]; then
      echo "Failed to upload objects to bucket '$test_bucket_name'."
      exit 1
    fi

    # Validar o último objeto usando head-object
    last_object_name="${quantity}-${size}/arquivo_$quantity.txt"

    start_time=$(date +%s%3N)
    validate_key_in_objects "head-object" "$profile" "$test_bucket_name" "$last_object_name"
    end_time=$(date +%s%3N)
    head_object_time=$((end_time - start_time))

    # Salvar resultados no CSV
    echo "$quantity,$size,$workers,head-object,$profile,$client,$head_object_time" >> ./report/report-inconsistencies.csv

    # Limpar o bucket
    rclone purge $profile:$test_bucket_name > /dev/null
    rm -rf "./temp-report-${quantity}-${size}"
  End
End

# Testes com delete e validações

Describe '1, delete-object'
  setup(){
    bucket_name="test-delete-object-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "delete object on profile $1 using client $2" id:"194"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null
    aws --profile $profile s3api delete-object --bucket $test_bucket_name --key $file1_name > /dev/null

    start_time=$(date +%s%3N)
    validate_key_in_objects "list-objects" "$profile" "$test_bucket_name" "None"
    end_time=$(date +%s%3N)
    deletion_time=$((end_time - start_time))

    # Salvar resultados no CSV
    echo "1,1,1,delete-object,$profile,$client,$deletion_time" >> ./report/report-inconsistencies.csv

    # Limpar o bucket
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

Describe 'Parameter, delete-objects'
  setup(){
    bucket_name="test-delete-objects-$(date +%s)"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
    $QUANTITY
    $WORKERS
    $SIZE
  End
  Example "delete $3 objects on profile $1 using client $2" id:"194"
    profile=$1
    client=$2
    quantity=$3
    workers=$4
    size=$5
    test_bucket_name="$bucket_name-$client-$profile"

    # Criar o bucket
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    if [ $? -ne 0 ]; then
      echo "Failed to create bucket '$test_bucket_name'."
      exit 1
    fi

    create_temp_objects $quantity $size

    mgc workspace set $profile > /dev/null
    mgc object-storage objects upload-dir ./temp-report-${quantity}-${size} $test_bucket_name/${quantity}-${size}/ --workers $workers

    aws --profile $profile s3 rm s3://$test_bucket_name --recursive > /dev/null
    start_time=$(date +%s%3N)
    validate_key_in_objects "list-objects" "$profile" "$test_bucket_name" "None"
    end_time=$(date +%s%3N)
    deletion_time=$((end_time - start_time))

    echo "$quantity,$size,$workers,delete-objects,$profile,$client,$deletion_time" >> ./report/report-inconsistencies.csv

    rclone purge $profile:$test_bucket_name > /dev/null
    rm -rf "./temp-report-${quantity}-${size}"
  End
End

### Versioned tests

# Testes com 1 objeto sem paralelismo

Describe '1, get-object-versioned'
  setup(){
    bucket_name="test-194-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "bucket exists on profile $1 using client $2" id:"194"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws s3api put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null

    case "$client" in
      "aws-s3api" | "aws" | "aws-s3" | "rclone" | "mgc")
        start_time=$(date +%s%3N)
        validate_key_in_objects "get-object" "$profile" "$test_bucket_name" "$file1_name"
        if [ $? -eq 0 ]; then
          echo "Key '$file1_name' found in bucket '$test_bucket_name'."
        else
          echo "Key '$file1_name' not found in bucket '$test_bucket_name'."
        fi
        end_time=$(date +%s%3N)
        object_exists_time=$((end_time - start_time))
        ;;
    esac
    echo "1,1,1,get-object-versioned,$profile,$client,$object_exists_time" >> ./report/report-inconsistencies.csv
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

Describe '1, list-objects-versioned'
  setup(){
    bucket_name="test-194-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "bucket exists on profile $1 using client $2" id:"194"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws s3api put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null

    case "$client" in
      "aws-s3api" | "aws" | "aws-s3" | "rclone" | "mgc")
        start_time=$(date +%s%3N)
        validate_key_in_objects "list-objects" "$profile" "$test_bucket_name" "$file1_name"
        end_time=$(date +%s%3N)
        object_exists_time=$((end_time - start_time))
        ;;
    esac
    echo "1,1,1,list-objects-versioned,$profile,$client,$object_exists_time" >> ./report/report-inconsistencies.csv
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

Describe '1, head-object-vesioned'
  setup(){
    bucket_name="test-194-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "bucket exists on profile $1 using client $2" id:"194"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws s3api put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null

    case "$client" in
      "aws-s3api" | "aws" | "aws-s3" | "rclone" | "mgc")
        start_time=$(date +%s%3N)
        validate_key_in_objects "head-object" "$profile" "$test_bucket_name" "$file1_name"
        if [ $? -eq 0 ]; then
          echo "Key '$file1_name' found in bucket '$test_bucket_name'."
        else
          echo "Key '$file1_name' not found in bucket '$test_bucket_name'."
        fi
        end_time=$(date +%s%3N)
        object_exists_time=$((end_time - start_time))
        ;;
    esac
    echo "1,1,1,head-object-vesioned,$profile,$client,$object_exists_time" >> ./report/report-inconsistencies.csv
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

# Testes com parametros de quantidade, tamanho e workers

Describe 'Parameter, get-object-versioned'
  setup(){
    bucket_name="test-get-object-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
    $QUANTITY
    $WORKERS
    $SIZE
  End
  Example "bucket exists on profile $1 using client $2 with $3 objects" id:"194"
    profile=$1
    client=$2
    quantity=$3
    workers=$4
    size=$5
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws s3api put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null

    create_temp_objects $quantity $size
    mgc workspace set $profile > /dev/null
    mgc object-storage objects upload-dir ./temp-report-${quantity}-${size} $test_bucket_name/${quantity}-${size}/ --workers $workers

    # Validar o último objeto usando get-object
    last_object_name="${quantity}-${size}/arquivo_$quantity.txt"
    start_time=$(date +%s%3N)
    validate_key_in_objects "get-object" "$profile" "$test_bucket_name" "$last_object_name"
    if [ $? -eq 0 ]; then
      echo "Key '$last_object_name' found in bucket '$test_bucket_name' using get-object."
    else
      echo "Key '$last_object_name' not found in bucket '$test_bucket_name' using get-object."
    fi
    end_time=$(date +%s%3N)
    get_object_time=$((end_time - start_time))

    # Salvar resultados no CSV
    echo "$quantity,$size,$workers,get-object-versioned,$profile,$client,$get_object_time" >> ./report/report-inconsistencies.csv

    # Limpar o bucket
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

Describe 'Parameter, list-objects-versioned'
  setup(){
    bucket_name="test-list-objects-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
    $QUANTITY
    $WORKERS
    $SIZE
  End
  Example "bucket exists on profile $1 using client $2 with $3 objects" id:"194"
    profile=$1
    client=$2
    quantity=$3
    workers=$4
    size=$5
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws s3api put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null

    create_temp_objects $quantity $size
    mgc workspace set $profile > /dev/null
    mgc object-storage objects upload-dir ./temp-report-${quantity}-${size} $test_bucket_name/${quantity}-${size}/ --workers $workers

    # Validar o último objeto usando list-objects
    last_object_name="${quantity}-${size}/arquivo_$quantity.txt"
    start_time=$(date +%s%3N)
    validate_key_in_objects "list-objects" "$profile" "$test_bucket_name" "$last_object_name"
    if [ $? -eq 0 ]; then
      echo "Key '$last_object_name' found in bucket '$test_bucket_name' using list-objects."
    else
      echo "Key '$last_object_name' not found in bucket '$test_bucket_name' using list-objects."
    fi
    end_time=$(date +%s%3N)
    list_objects_time=$((end_time - start_time))

    # Salvar resultados no CSV
    echo "$quantity,$size,$workers,list-objects-versioned,$profile,$client,$list_objects_time" >> ./report/report-inconsistencies.csv

    # Limpar o bucket
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

Describe 'Parameter, head-object-versioned'
  setup(){
    bucket_name="test-head-object-$(date +%s)-$RANDOM"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
    $QUANTITY
    $WORKERS
    $SIZE
  End
  Example "bucket exists on profile $1 using client $2 with $3 objects" id:"194"
    profile=$1
    client=$2
    quantity=$3
    workers=$4
    size=$5
    test_bucket_name="$bucket_name-$client-$profile"

    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws s3api put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null


    create_temp_objects $quantity $size
    if [ ! -d "./temp-report-${quantity}-${size}" ]; then
      echo "Directory './temp-report-${quantity}-${size}' does not exist."
      exit 1
    fi

    # Fazer upload dos objetos
    mgc workspace set $profile > /dev/null
    mgc object-storage objects upload-dir ./temp-report-${quantity}-${size} $test_bucket_name/${quantity}-${size}/ --workers $workers
    if [ $? -ne 0 ]; then
      echo "Failed to upload objects to bucket '$test_bucket_name'."
      exit 1
    fi

    # Validar o último objeto usando head-object
    last_object_name="${quantity}-${size}/arquivo_$quantity.txt"

    start_time=$(date +%s%3N)
    validate_key_in_objects "head-object" "$profile" "$test_bucket_name" "$last_object_name"
    end_time=$(date +%s%3N)
    head_object_time=$((end_time - start_time))

    # Salvar resultados no CSV
    echo "$quantity,$size,$workers,head-object-versioned,$profile,$client,$head_object_time" >> ./report/report-inconsistencies.csv

    # Limpar o bucket
    rclone purge $profile:$test_bucket_name > /dev/null
    rm -rf "./temp-report-${quantity}-${size}"
  End
End

# Testes com delete e validações

Describe '1, delete-object-versioned'
  setup(){
    bucket_name="test-delete-object-$(date +%s)"
    file1_name="LICENSE"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
  End
  Example "delete object on profile $1 using client $2" id:"194"
    profile=$1
    client=$2
    test_bucket_name="$bucket_name-$client-$profile"
    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws s3api put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null
    aws --profile $profile s3 cp $file1_name s3://$test_bucket_name > /dev/null
    aws --profile $profile s3api delete-object --bucket $test_bucket_name --key $file1_name > /dev/null

    start_time=$(date +%s%3N)
    validate_key_in_objects "list-objects" "$profile" "$test_bucket_name" "None"
    end_time=$(date +%s%3N)
    deletion_time=$((end_time - start_time))

    # Salvar resultados no CSV
    echo "1,1,1,delete-object-versioned,$profile,$client,$deletion_time" >> ./report/report-inconsistencies.csv

    # Limpar o bucket
    rclone purge $profile:$test_bucket_name > /dev/null
  End
End

Describe 'Parameter, delete-objects-versioned'
  setup(){
    bucket_name="test-delete-objects-$(date +%s)"
  }
  Before 'setup'
  Parameters:matrix
    $PROFILES
    $CLIENTS
    $QUANTITY
    $WORKERS
    $SIZE
  End
  Example "delete $3 objects on profile $1 using client $2" id:"194"
    profile=$1
    client=$2
    quantity=$3
    workers=$4
    size=$5
    test_bucket_name="$bucket_name-$client-$profile"

    aws --profile $profile s3 mb s3://$test_bucket_name > /dev/null
    aws s3api put-bucket-versioning --bucket $test_bucket_name --versioning-configuration Status=Enabled > /dev/null

    create_temp_objects $quantity $size

    mgc workspace set $profile > /dev/null
    mgc object-storage objects upload-dir ./temp-report-${quantity}-${size} $test_bucket_name/${quantity}-${size}/ --workers $workers

    aws --profile $profile s3 rm s3://$test_bucket_name --recursive > /dev/null
    start_time=$(date +%s%3N)
    validate_key_in_objects "list-objects" "$profile" "$test_bucket_name" "None"
    end_time=$(date +%s%3N)
    deletion_time=$((end_time - start_time))

    echo "$quantity,$size,$workers,delete-objects-versioned,$profile,$client,$deletion_time" >> ./report/report-inconsistencies.csv

    rclone purge $profile:$test_bucket_name > /dev/null
    rm -rf "./temp-report-${quantity}-${size}"
  End
End
