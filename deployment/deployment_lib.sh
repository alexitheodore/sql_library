#!/usr/bin/env bash

# exit on any error
set -e

# defaults:
username=db_architect
refresh="FALSE"
reset="FALSE"
upgrade="FALSE"
port=5432

# Get local defaults (which may override)

source env_variables.sh.local
source schema/dbv_id
git_commit_id=`git rev-parse --short HEAD`

### get inputs ### <<..
PROGNAME=$0
#description should come from the calling source

usage() {
	cat << EOF >&2

Usage: $PROGNAME -h <host> [-U <username>] [-d <database>] [-p <port>] [OPTIONS]

$DESCRIPTION

At baseline (without any arguments), the deployment script runs at "refresh" mode, which only affects non-schema elements (views, procedures,
permissions, etc.) and runs tests. All other options are additive (unless specified otherwise).

Connection:
-h <postgres host>: host url or IP (required)
-U <postgres username>: connecting username (DEFAULT "$username")
-d <database name>: connecting database name
-p <port>: destination port (DEFAULT "$port")

OPTIONS (no action take by default):
-f : do not prompt Y/n to continue
-r : Refresh mode - refresh all "non-data" objects (Functions, Views, etc.)
-R : Reset mode - build entire database from scratch and then reload all data; Implies "-r"
-u : Upgrade mode - Refresh mode + run schema upgrade scripts; Implies "-r"
-b : verbose info
-D : debug - shows sql script plan without running it

Local settings taken from 'env_variables.sh.local'

Default and Local Env settings are:

username: $username
action: $action
refresh: $refresh
reset: $reset
upgrade: $upgrade
port: $port
database: $database
host: $host
dbv_id: $dbv_id



EOF
	exit 1
}

while getopts 'h:U:d:p:s:rRubD?' o; do
	case $o in
		(h) host=$OPTARG;;
		(U) username=$OPTARG;;
		(d) database=$OPTARG;;
		(p) port=$OPTARG;;
		(s) data_source=$OPTARG;;
		(r) refresh="TRUE";;
		(R) reset="TRUE"; refresh="TRUE";;
		(u) upgrade="TRUE"; refresh="TRUE";;
		(b) verbose="-b -e";;
		(D) debug="TRUE";;
		(*) usage #catch any unaccepted parameters
	esac
done
shift "$((OPTIND - 1))"

#..>>

### 


echo -e "You are connecting to \033[0;31m$host:$database\033[0;39m as $username on port $port."


if [[ -z "$host" ]]
then
	echo "Error: The host name must be provided."
	exit
fi

if [[ -z "$database" ]]
then
	echo "Error: The database must be provided."
	exit
fi

if [[ "$env" = "dev" ]]; then
  mre_flags="{not-verbose}"
  is_dev=TRUE
else
  mre_flags="{verbose}"
  is_dev=FALSE
fi


psql_build() {

  # ! all lines must begin with a space
	psql_exec+=" PGOPTIONS='--client-min-messages=warning'"
	psql_exec+=" psql -h $host -U $username -p $port --dbname=postgres"
	psql_exec+=" -q $verbose -v ON_ERROR_STOP=ON"
	psql_exec+=" -v reset=$reset -v refresh=$refresh -v upgrade=$upgrade -v mre_flags=$mre_flags -v is_dev=$is_dev -v is_prod=$is_prod"
	psql_exec+=" -v git_commit_id=$git_commit_id -v dbv_id=$dbv_id"
	psql_exec+=" -v dwh_host=$dwh_host -v dwh_port=$dwh_port -v dwh_dbname=$dwh_dbname"
	psql_exec+=" -v apif_prod_host=$apif_prod_host -v apif_prod_port=$apif_prod_port -v apif_prod_dbname=$apif_prod_dbname"

  psql_exec+=" $* "

	if [[ "$debug" = "TRUE" ]]
  then
    echo "DEBUG: $psql_exec"
    exit
  fi

}

show_success() {
  echo -e "\033[0;32mSUCCESS!\033[0;39m"
  echo "Finished $(date)"
}


get_current_dbv_id () {
	
	psql_code=(
		"-t -c \"select max(dbv_id) from deployment_logs;\""
		)

	psql_build ${psql_code[@]}

	current_dbv_id=$( eval $psql_exec )
}
