#!/usr/bin/env bash

# Put here hosts, which should be able to connect with DB
ALLOWED_HOSTS=("172.10.0.1/32" "172.10.0.2/32")
POSTGRES_HBA=/var/lib/postgresql/data/pg_hba.conf
POSTGRES_CONF=/var/lib/postgresql/data/postgresql.conf
# Variables $POSTGRES_DB $POSTGRES_USER are specified
# via docker-compose and automatically generated inside container
# so there is no necessary to re-create them.

echo "= PGConfigurator ="
echo "Script performs basic service configuration for PostgreSQL"
echo ""
echo "Applying changes to pg_hba.conf..."
echo "Making backup..."
cp $POSTGRES_HBA $POSTGRES_HBA.bak

sed -i -e "s/^host all all all \(md5\|trust\)$//g" $POSTGRES_HBA

list_len=${#ALLOWED_HOSTS[@]}
for host in $(seq 0 $[list_len-1])
do
  # Sed another delimiter
  # https://stackoverflow.com/a/20808365/9342492

  if ! [[ $(sed -n -e "\~^host $POSTGRES_DB $POSTGRES_USER ${ALLOWED_HOSTS[host]} md5~p" $POSTGRES_HBA) ]]
  then
    echo -e "## Changed by PGConfigurator\nhost $POSTGRES_DB $POSTGRES_USER ${ALLOWED_HOSTS[host]} md5" >> $POSTGRES_HBA
    echo "Host ${ALLOWED_HOSTS[host]} added to pg_hba.conf"
  else
    echo "Host ${ALLOWED_HOSTS[host]} already presented in pg_hba.conf"
  fi
done

if ! [[ $(sed -n -e "/^host all all all reject/p" $POSTGRES_HBA) ]]
  then
    echo -e "## Changed by PGConfigurator\nhost all all all reject" >> $POSTGRES_HBA
fi

echo ""
echo "Applying custom postgres.conf..."
echo "Making backup..."
cp $POSTGRES_CONF $POSTGRES_CONF.bak
echo "Setting params..."
echo ""

pg_params=(
  "listen_addresses='*'"
  "max_connections=200"
  "password_encryption=md5"
  "shared_buffers=256MB"
  "work_mem=4MB"
  "maintenance_work_mem=64MB"
  "dynamic_shared_memory_type=posix"
  "effective_io_concurrency=200"
  "wal_buffers=7864kB"
  "max_wal_size=2GB"
  "min_wal_size=1GB"
  "checkpoint_completion_target=0.7"
  "random_page_cost=1.1"
  "effective_cache_size=768MB"
  "default_statistics_target=100"
  "log_destination='stderr'"
  "logging_collector=off"
  "log_min_messages=info"
  "log_min_error_statement=error"
  "log_min_duration_statement=0"
  "log_connections=on"
  "log_disconnections=off"
  "log_duration=on"
  "log_hostname=on"
  "log_line_prefix='[%m] - %p %q - %u@%h:%d - %a '"
  "log_statement='ddl'"
  "log_timezone='localtime'"
)

# Do not change!
pg_params_len=${#pg_params[@]}

for x in $(seq 0 $[pg_params_len-1])
do
  param=${pg_params[$x]}

  # Convert to array
  IFS="=" read -r -a i <<< "${param}"

  searched_value="#*${i[0]}[[:blank:]]=[[:blank:]][[[:print:]][^#]\{0,\}"
  new_value="## Changed by PGConfigurator\n${i[0]} = ${i[1]}"

  echo "Setting ${i[0]} param..."
    if [[ $(sed -n -e "\~^${i[0]}[[:blank:]]=[[:blank:]]${i[1]}~p" $POSTGRES_CONF) ]]
    then
      echo "${i[0]} = ${i[1]} already presented, not overrided"
    elif [[ $(sed -n -e "\~^$searched_value~p" $POSTGRES_CONF) ]]
    then
      sed -i -e "s~^$searched_value~$new_value ~" $POSTGRES_CONF
      echo "Changed to: ${i[0]} = ${i[1]}"
    else
      # Parameter -e allow to escape newline character
      echo -e "## Added by PGConfigurator\n${i[0]} = ${i[1]}" >> $POSTGRES_CONF
      echo "${i[0]} = ${i[1]} not presented, added"
    fi
done

echo ""
echo "Script finished"
