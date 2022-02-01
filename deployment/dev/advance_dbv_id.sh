# exit on any error
set -e

source ../../schema/dbv_id

echo "dbv_id=$(($dbv_id + 1))" > ../../schema/dbv_id

cat ../sql_lib/patches.sql.tpl > ../../schema/patches.sql