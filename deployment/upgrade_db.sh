#!/usr/bin/env bash

set -e
cd ../deployment/

read -p "Upgrade db 'source' to current DBV?" -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then



  # 1. checkout prod branch

  git pull
  git checkout prod -f
  # consider: git fetch origin && git reset --hard origin/prod && git clean -f -d

  # 2. run build

  sudo -u postgres bash build_db.sh -u

fi
