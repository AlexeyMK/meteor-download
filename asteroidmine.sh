#!/bin/bash
# Download the user's prod db into a local meteor db for testing/etc.

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
METEOR_PROJECT_DIR=`pwd`
if [ $2 ] ; then
  METEOR_PROJECT_DIR=$2
fi

if [ ! -d $METEOR_PROJECT_DIR/.meteor ] ; then
  echo "$METEOR_PROJECT_DIR doesn't seem to have a valid Meteor project"
  exit 1
fi

echo "-----------------------------------------------------------"
echo "Starting to download from server"
echo "(if your deployment has a password, it will be needed here)"
echo "-----------------------------------------------------------"

METEOR_APP_URL=$1
MONGO_SERVER_URL=$(meteor mongo --url $METEOR_MONGO_URL)
#2.  mongodump server into temp
# sample mongo url: mongodb://client:THIS-IS-PASSWORD@MONGO-SERVER-URL/DATABASE-URL
# kind of a hacky regex, would love some help.
MONGO_SERVER_PW=$(echo $MONGO_SERVER_PW | sed "s|mongodb://client:\(.*\)@.*|\1|")
MONGO_SERVER_HOST=$(echo $MONGO_SERVER_PW | sed "s|.*@\(.*\)/.*|\1|")
MONGO_SERVER_DBNAME=$(echo $MONGO_SERVER_PW | sed "s|.*/\(.*\)|\1|")
mongodump --user client --host $MONGO_SERVER_HOST --db $MONGO_SERVER_DBNAME --password $MONGO_SERVER_PW --out /tmp/asteroidmine.mongodump


#4.  mongorestore into local
echo mongorestore --db meteor -h localhost --port 3002 --drop secondscreen_meteor_com/
#5.  remove temp
