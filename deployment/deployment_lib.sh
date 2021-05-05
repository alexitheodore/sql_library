#!/usr/bin/env bash

# exit on any error
set -e

cd ../deployment/


# defaults:
username=db_architect
action="ROLLBACK;"
rebuild="FALSE"
port=5432

# Get local defaults (which may override)
source env_variables.sh.local
source commit_id.git

### get inputs ### <<..
PROGNAME=$0
#description should come from the calling source

usage() {
	cat << EOF >&2

Usage: $PROGNAME -h <host> [-U <username>] [-d <database>] [-p <port>] [-CfrRb]

$DESCRIPTION

Connection:
-h <postgres host>: host url or IP (required)
-U <postgres username>: connecting username (DEFAULT "$username")
-d <database name>: connecting database name
-p <port>: destination port (DEFAULT "$port")

Deployment:
-C : "COMMIT" mode - if omitted, all transactions are rolled back (DEFAULT disabled)
-f : "Force" mode - do not prompt Y/n when comitting (DEFAULT disabled); Implies -C
-r : Reload mode - rebuild tables (DEFAULT disabled)
-R : Reset HARD mode - build entire database from scratch and then reload (DEFAULT disabled); Implies "-xrC"
-v : verbose mode
-x : "unsafe" mode - no transaction control; Implies -C

Local settings taken from 'env_variables.sh.local'

Default and Local Env settings are:

username: $username
action: $action
rebuild: $rebuild
port: $port
database: $database
host: $host



EOF
	exit 1
}

while getopts 'h:U:d:p:s:CfrbRx?' o; do
	case $o in
		(h) host=$OPTARG;;
		(U) username=$OPTARG;;
		(d) database=$OPTARG;;
		(p) port=$OPTARG;;
		(s) data_source=$OPTARG;;
		(C) action="COMMIT;";;
		(f) force="force"; action="COMMIT;";;
		(r) rebuild="TRUE";;
		(R) reset="TRUE"; unsafe="TRUE"; rebuild="TRUE"; action="COMMIT;";;
		(v) verbose="-b -e";;
		(x) unsafe="TRUE"; action="COMMIT;";;
		(*) usage #catch any unaccepted parameters
	esac
done
shift "$((OPTIND - 1))"

#..>>

### 


echo -e "You are connected to \033[0;31m$host:$database\033[0;39m as $username on port $port."



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


mode_alert() {
	shopt -s nocasematch

	if [[ "$action" = "COMMIT;" ]]
	then 
		echo -e "\033[0;31m!!! COMMIT MODE !!!\033[0;39m"
		if [[ "$force" != "force" ]]
		then 
			if [[ "$reset" = "TRUE" ]]
			then
				read -p "Are you sure you want to RESET HARD (this will be done in COMMIT mode!)? (Y/n)" -n 1 -r
			else
				read -p "Are you sure you want to commit? (Y/n)" -n 1 -r
			fi

			echo    # (optional) move to a new line
			if [[ ! $REPLY =~ ^[Yy]$ ]]
			then
				echo "Ok, exiting..."
			    exit 0
			fi
		fi
	else	
		echo -e "\033[0;33m~~TESTING MODE~~ (no changes will be made)\033[0;39m"
		action=ROLLBACK
	fi
}


psql_build() {

	psql_exec+="PGOPTIONS='--client-min-messages=warning' "
	psql_exec+="psql -h $host -U $username -p $port --dbname=$database "
	psql_exec+="-q $verbose -v ON_ERROR_STOP=ON "
	psql_exec+="-v rebuild=$rebuild -v git_commit_id=$git_commit_id "
	
	if [[ "$unsafe" = "TRUE" ]]
	then
		psql_exec+="$* "
	else
		psql_exec+="-c \"BEGIN;\" "
		psql_exec+="$* "
		psql_exec+="-c \"$action;\" "
	fi

}

show_success() {
	if [[ "$action" = "COMMIT;" ]]
	then 
		echo -e "\033[0;32mSUCCESS! COMMITTED.\033[0;39m"
	else	
		echo -e "\033[0;33mTest Succeeded.\033[0;39m"
		action=ROLLBACK
	fi
	
	echo "Finished $(date)"
}
