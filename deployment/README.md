# Files

## build_db.sh

This is the main script that is used to deploy database changes. It executes all the schema operations via `build_db.sql`. The file can be customized as needed; the default template is provided in the sql_library and should be copied to the root dir of the repo.

## deployment_lib.sh

This file contains all the scripts needed in `build_db.sh`. 

## env_variables_sh.local

This file contains local configuration settings for the deployment and should be placed at the root of the repo. The default file with accepted options and formats `env_variables.sh.default` provides a template.

_note: the `.local` file ending causes the file to be ignored in the repo and changes therefore should not be committed.

## upgrade_db.sh

-- todo: convert to default template
-- todo: place real file in repo root
-- todo: adapt file to new methods as in LDT


# Usage

Deployment is done by calling the `build_db.sh` script from the repo root dir.

$ `bash build_db.sh -?`

Will show the help screen.

Connection settings such as the destination database host, port, username, etc. are all configurable in the following file, which should be in the root directory:

`env_variables.sh.local`

However, these parameters can also be over-ridden from the CLI - see the help screen.


There are various deployment modes depending on environment and circumstance.

## Deployment Modes:

### Upgrade

$ `bash build_db.sh -u`

Upgrading increments the database in place by executing curated scripts for schema and data changes and then doing a total refresh (see below) of everything else. This mode is intended for Production environments. No data should ever be lost in this mode (except in the rare circumstance where a feature is intentionally depreciated.)

### Reset

$ `bash build_db.sh -R`

Resetting wipes the database and builds it back up from scratch. Because this mode is normally used only in Dev environments, it restores the standardized dev data ([dev_data_standard.sql](../../schema/data/dev_data_standard.sql))- which means that all data will be wiped clear and restored back to "factory" reset conditions.

### Refresh

$ `bash build_db.sh -r`

A refresh restores all non-volatile schema (functions, triggers, etc.) back to their intended state and configuration. It is safe to use in a Production environment, though should normally not be needed. 

Examples of when refreshing could be used: an unintended modification was made manually (by an admin) either during a hot fix or a hot test that needs to be restored.


# Database Versions

Code versioning is done using minor and major releases. Major releases are grouped under a `dbv_id` and are tagged as such in the git repo. Deployment of upgrades can only be done in major version releases. Minor versions, which are tracked simply by their git commit hashes, only track progress within a major version.