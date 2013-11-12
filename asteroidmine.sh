#!/bin/bash
# Download the user's prod db into a local meteor db for testing/etc.

USAGE="Usage: asteroidmine.sh YOURAPP.meteor.com [local meteor directory, defaults to .]"
TEMP_DUMP_LOCATION=/tmp/asteroidmine.mongodump
# 1. Ensure user has meteor & mongo installed and available in path
if [ ! $(which meteor) ] ; then
  echo "Meteor is not installed on this computer (or at least it's not in the PATH)"
  echo "install Meteor by running"
  echo "> curl https://install.meteor.com | /bin/sh"
  exit 1
fi

if [ ! $(which mongodump) ] ; then
  echo "Need to install mongo separately from Meteor first (meteor only installs"
  echo "the bare minimum mongo, and doesn't include the utilities we need)"
  echo ""
  echo "1. Try 'brew install mongodb'"
  echo ""
  echo "2. If that doesn't work, follow the manual steps at"
  echo "http://docs.mongodb.org/v2.4/installation/"
# TODO: offer user to install mongo manually on their behalf, though this
# is a little ambitious, especially beyond OSX.
  exit 1
fi

# 2. Ensure project exists in proper directory
ORIGINAL_DIR=$(pwd)
METEOR_PROJECT_DIR=$(pwd)
if [ $2 ] ; then
  METEOR_PROJECT_DIR=$2
fi

if [ ! -d $METEOR_PROJECT_DIR/.meteor ] ; then
  echo "$METEOR_PROJECT_DIR doesn't seem to have a valid Meteor project"
  echo $USAGE
  exit 1
fi

echo "-----------------------------------------------------------"
echo "Starting to download from server"
echo "(if your deployment has a password, it will be needed here)"
echo "-----------------------------------------------------------"

METEOR_APP_URL=$1
cd $METEOR_PROJECT_DIR
#MONGO_SERVER_URL=$(meteor mongo --url $METEOR_MONGO_URL)
#MONGO_SERVER_URL="mongodb://client:THIS-IS-PASSWORD@MONGO-SERVER-URL/DATABASE-URL"

# kind of a hacky regex, would love some help.
MONGO_SERVER_PW=$(echo $MONGO_SERVER_URL | sed "s|mongodb://client:\(.*\)@.*|\1|")
MONGO_SERVER_HOST=$(echo $MONGO_SERVER_URL| sed "s|.*@\(.*\)/.*|\1|")
MONGO_SERVER_DBNAME=$(echo $MONGO_SERVER_URL | sed "s|.*/\(.*\)|\1|")

rm -r $TEMP_DUMP_LOCATION
mongodump --username client --host $MONGO_SERVER_HOST --db $MONGO_SERVER_DBNAME --password $MONGO_SERVER_PW --out $TEMP_DUMP_LOCATION

# TODO check exit code
echo "-----------------------------------------------------------"
echo "Uploading DB into your local meteor instance"
echo "-----------------------------------------------------------"

if [ -n "$(ps ax | grep -e mongod | grep -v grep)" ] ; then
  echo Mongo already running.
else
  # TODO - more than port 3000
  echo "starting local version of meteor (needed for database daeamon)"
  meteor &
fi

mongorestore --db meteor -h localhost --port 3002 --drop $TEMP_DUMP_LOCATION/$MONGO_SERVER_DBNAME/

echo "-----------------------------------------------------------"
echo "All done, enjoy!"
echo "-----------------------------------------------------------"
# TODO ensure exit code is correct
cd $ORIGINAL_DIR
