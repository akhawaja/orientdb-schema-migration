#!/usr/bin/env bash

# OrientDB Schema Migration
#
# Copyright © 2015 Amir Khawaja <khawaja.amir@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

if [[ -z "$ORIENTDB_HOME" ]]; then
    echo "ORIENTDB_HOME environment variable must be set before running this script"
    exit 1
fi

# Globals
ODB_CONSOLE=${ORIENTDB_HOME}/bin/console.sh
NOW="$(date -u +%Y%m%d%H%M%S)"
NEWLINE=$'\n'

# Functions
function ensure_migrations_opt()
{
    if [ -z "$OSQL_DIRECTORY" ]; then
        echo "Migrations directory name is missing"
        exit 1
    fi
}

function create_migration()
{
    ensure_migrations_opt

    CWD=$(pwd)
    if [ ! -d "${CWD}/${OSQL_DIRECTORY}" ]; then
        mkdir "${CWD}/${OSQL_DIRECTORY// /_}"
        touch "${CWD}/${OSQL_DIRECTORY}/${NAME}"
    else
        touch "${CWD}/${OSQL_DIRECTORY}/${NAME}"
    fi
}

function run_migrations()
{
    ensure_migrations_opt

    CWD=$(pwd)
    CONN="CONNECT remote:${DB_HOST}/${DB_NAME} ${DB_USER} ${DB_PASSWORD};"
    VERTEX_CHECK="js var result = null;result = db.query(\"SELECT FROM (SELECT EXPAND(classes) FROM metadata:schema) "
    VERTEX_CHECK+="WHERE name = 'Migration'\");if (result.length === 0) {print('MIGRATION_NOT_FOUND');}"
    VERTEX_CHECK+=";end;exit"
    CMD="${CONN}${VERTEX_CHECK}"
    TMPFILE=`mktemp /tmp/${NOW}.XXXXXX` || exit 1
    echo "${CMD}" > "${TMPFILE}"
    RESULT=$(${ODB_CONSOLE} ${TMPFILE})
    rm -f ${TMPFILE}

    if grep -q "MIGRATION_NOT_FOUND Client" <<<$RESULT; then
        MIGRATION_SQL="CREATE CLASS Migration EXTENDS V;"
        MIGRATION_SQL+="CREATE PROPERTY Migration.filename STRING;"
        MIGRATION_SQL+="CREATE PROPERTY Migration.created DATETIME;"
        MIGRATION_SQL+="CREATE INDEX Migration.filename ON Migration(filename COLLATE CI) FULLTEXT;"
        CMD="${CONN}${MIGRATION_SQL}"
        TMPFILE=`mktemp /tmp/${NOW}.XXXXXX` || exit 1
        echo "${CMD}" > "${TMPFILE}"
        RESULT=$(${ODB_CONSOLE} ${TMPFILE})
        rm -f ${TMPFILE}
    fi

    for file in $(find "${CWD}/${OSQL_DIRECTORY}" -name "${MIGRATE}" -print | sort); do
        CONTENT=$(<"${file}")
        FILENAME=${file##*/}
        VERTEX_CHECK="js var result = db.query(\"SELECT FROM Migration WHERE filename = '${FILENAME}'\");"
        VERTEX_CHECK+="if (result.length > 0) {print('MIGRATION_EXISTS');}"
        VERTEX_CHECK+=";end;exit"
        CMD="${CONN}${VERTEX_CHECK}"
        TMPFILE=`mktemp /tmp/${NOW}.XXXXXX` || exit 1
        echo "${CMD}" > "${TMPFILE}"
        RESULT=$(${ODB_CONSOLE} ${TMPFILE})
        rm -f ${TMPFILE}

        if grep -q "MIGRATION_EXISTS Client" <<<$RESULT; then
            echo "Skipping migration: ${file}"
            continue
        else
            DT=$(date -u +"%Y-%m-%d %H:%M:%S")
            POST="CREATE VERTEX Migration SET filename = '${FILENAME}', created = '${DT}';"

            if [ -n "$CONTENT" ]; then
                echo "Running migration: ${file}"
                CMD="${CONN}${CONTENT}${POST}"
                TMPFILE=`mktemp /tmp/${NOW}.XXXXXX` || exit 1
                echo "${CMD}" > "${TMPFILE}"
                RESULT=$(${ODB_CONSOLE} ${TMPFILE})
                rm -f ${TMPFILE}
            fi
        fi
    done

    rm -f "${CWD}/0"
    echo "Done running migrations."
}

function usage()
{
    cat <<EOF
    Usage: odb-migrations.sh [TASK] [OPTIONS]

    Examples:

      Create migration:
        odb-migrations.sh -c "my first migration script" -d "migrations"

      Run migrations:
        odb-migrations.sh -m "*" -d "migrations" -u myusername -p mypassword -h localhost -n "my-db-name"

    Task:

    -c|--create                Create a new migration.
    -m|--migrate               Run migrations starting from pattern. e.g. "*" or "20151002*".

    Options:

    -d|--migrations-directory  Folder where the migrations live.
    -u|--db-user               OrientDB username.
    -p|--db-password           OrientDB password.
    -h|--db-host               OrientDB host name.
    -n|--db-name               OrientDB name.
EOF
}

# Parse all the command-line options
while [[ $# > 1 ]]
do
key="$1"

case $key in
    -c|--create)
    NAME="${NOW}_${2// /_}.osql"
    shift # past argument
    ;;
    -m|--migrate)
    MIGRATE="${2}.osql"
    shift # past argument
    ;;
    -d|--migrations-directory)
    OSQL_DIRECTORY="$2"
    shift # past argument
    ;;
    -u|--db-user)
    DB_USER="$2"
    shift # past argument
    ;;
    -p|--db-password)
    DB_PASSWORD="$2"
    shift # past argument
    ;;
    -h|--db-host)
    DB_HOST="$2"
    shift # past argument
    ;;
    -n|--db-name)
    DB_NAME="$2"
    shift #past argument
    ;;
    -s|--start-from)
    START_FROM="$2"
    shift # past argument
    ;;
esac
shift # past argument or value
done

# Execute the task
if [ -n "$NAME" ]; then
    create_migration
elif [ -n "$MIGRATE" ]; then
    run_migrations
else
    usage
fi
