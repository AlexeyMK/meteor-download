#!/bin/bash
# Download the user's prod db into a local meteor db for testing/etc.

USAGE="Usage: download.sh YOURAPP.meteor.com [local meteor directory, defaults to .]"
TEMP_DUMP_LOCATION=/tmp/meteor-download.mongodump

if [ ! $1 ] ; then
  echo $USAGE
  exit 1
fi

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
METEOR_LOCAL_DB=.meteor/local/db
if [ $2 ] ; then
  METEOR_PROJECT_DIR=$2
fi

if [ ! -d $METEOR_PROJECT_DIR/.meteor ] ; then
  echo "$METEOR_PROJECT_DIR doesn't seem to have a valid Meteor project"
  echo $USAGE
  exit 1
elif [ ! -d $METEOR_PROJECT_DIR/$METEOR_LOCAL_DB ] ; then
  echo "The database for $METEOR_PROJECT_DIR hasn't been initialized yet.  Initialize the database (by running 'meteor' or the equivalent) and then re-run this script"
  exit 1
fi

echo "-----------------------------------------------------------"
echo "Starting to download from server"
echo "(if your deployment has a password, it will be needed here)"
echo "-----------------------------------------------------------"

METEOR_APP_URL=$1
TEMPFILE=URL.tmp
cd $METEOR_PROJECT_DIR
# HACK: we have to let meteor mongo have stdout to prompt for password so we
# can't use $(...) and instead tee and tail the result
meteor mongo --url $METEOR_APP_URL | tee $TEMPFILE

if [ $PIPESTATUS -ne 0 ] ; then
  echo "Could not connect to your app's server."
  echo $USAGE
  exit 1
fi

MONGO_SERVER_URL=$(tail -n 1 $TEMPFILE)
rm $TEMPFILE

# regex works (tested) for what meteor.com returns for 0.7.0
# sample server url:mongodb://client:THIS-IS-PASSWORD@MONGO-SERVER-URL/DATABASE-URL
# for python version of similar tool: http://pydanny.com/parsing-mongodb-uri.html
MONGODUMP_ARGUMENTS=$(echo $MONGO_SERVER_URL | sed "s|mongodb://\([a-zA-Z0-9-]*\):\([a-zA-Z0-9-]*\)@\([a-zA-Z0-9\:.-]*\)/\(.*\)|--username \1 --password \2 --host \3 --db \4|")

if [ $? -ne 0 ] ; then
  echo "Failed to parse mongodump results, please take a look at this script (it may be outdated)"
  exit 1
fi

rm -r $TEMP_DUMP_LOCATION
mongodump $MONGODUMP_ARGUMENTS --out $TEMP_DUMP_LOCATION

if [ $? -ne 0 ] ; then
  echo "Mongodump Failed!"
  echo $USAGE
  exit 1
fi

# TODO - before you mongodump, save existing local DB somewhere as backup
echo "-----------------------------------------------------------"
echo "Uploading DB into your local meteor instance"
echo "-----------------------------------------------------------"

if [ -n "$(ps ax | grep -e mongod | grep -v grep)" ] ; then
  echo Mongo already running.
else
  # TODO - more than port 3000
  echo "starting local version of mongo db daemon"
  # hack: calling mongod directly because meteor is a mess to shut down after
  ~/.meteor/tools/latest/mongodb/bin/mongod --bind_ip 127.0.0.1 --smallfiles --nohttpinterface --port 3002 --dbpath ./$METEOR_LOCAL_DB &
  sleep 2 # hack - let mongo load
fi

# see http://stackoverflow.com/questions/3162385/how-to-split-a-string-in-shell-and-get-the-last-field
MONGO_SERVER_DBNAME=${MONGODUMP_ARGUMENTS##* }
mongorestore --db meteor -host localhost --port 3002 --drop $TEMP_DUMP_LOCATION/$MONGO_SERVER_DBNAME

kill $(jobs -pr)
sleep 1

# TODO ensure exit code is correct
#$?             #Return the exit status of the last command.
echo "-----------------------------------------------------------"
echo "All done, enjoy!"
echo "-----------------------------------------------------------"
cd $ORIGINAL_DIR
