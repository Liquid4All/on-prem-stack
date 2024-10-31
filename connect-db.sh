#!/bin/bash

source ./.env

PGOPTIONS=--search_path=$POSTGRES_SCHEMA pgcli postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@0.0.0.0:$POSTGRES_PORT/$POSTGRES_DB
