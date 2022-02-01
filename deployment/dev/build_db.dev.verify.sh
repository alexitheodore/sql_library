#!/usr/bin/env bash

# The purpose of this script is to simulate all forms up building (refresh, upgrade, reset) and then compare the
# results to make sure that they produce the same outcomes.

set -e

source env_variables.sh.local

echo "Refreshing..."
bash build_db.sh -r
sleep 1


echo "Rebuilding..."
bash build_db.sh -R
pg_dump --host=$host --username=$username --port=$port --dbname=$database \
  -s -O -x --schema=flywheel --schema=global --schema=app_catalog \
  -f pg_dump.api_flywheel.dev.reset.sql
sleep 1


echo "Upgrading..."
bash build_db.sh -u
pg_dump --host=$host --username=$username --port=$port --dbname=$database \
  -s -O -x --schema=flywheel --schema=global --schema=app_catalog \
  -f pg_dump.api_flywheel.dev.upgrade.sql
sleep 1


echo 'Comparing Dev Rebuilt Baseline with Dev Upgraded Baseline'

git diff --no-index pg_dump.api_flywheel.dev.upgrade.sql pg_dump.api_flywheel.dev.reset.sql

rm -f pg_dump.api_flywheel.dev.*