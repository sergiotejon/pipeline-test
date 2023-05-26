#!/bin/bash

# scripts/launch.sh [PIPELINE_TYPE] [PIPELINE_NAME]

# Usage example: 
# scripts/launch.sh custom e2e

NAMESPACE=pipelines-launcher

UPSTREAM=$(git rev-parse --abbrev-ref HEAD)
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse "$UPSTREAM")
BASE=$(git merge-base @ "$UPSTREAM")
COMMIT=$(git rev-parse HEAD)
REPOSITORY=$(git config --get remote.origin.url | cut -d ':' -f 2 | sed "s/\.git$//g")
BRANCH=$(git rev-parse --abbrev-ref HEAD)
AUTHOR_NAME=$(git config user.name)
AUTHOR_EMAIL=$(git config user.email)
PROJECT_NAME=$(echo ${REPOSITORY} | cut -d '/' -f 2)
PIPELINE_TYPE=$1
PIPELINE_NAME=$2

if [ $LOCAL = $REMOTE ]; then
  echo "Up-to-date: Launch webhook"

  kubectl port-forward -n ${NAMESPACE} \
    service/el-fc-launcher-custom-webhook-for-github 8080:8080 &
  PORT_FORWARD_PID=$!
  WEBHOOK_URL=http://localhost:8080/fc-launcher-custom-webhook-for-github
  until lsof -i:8080
  do
    printf "."
    sleep 1
  done 
  wget -O- -q \
    --header="X-Event-Key: repo:push" \
    --header="Content-Type:application/json" \
    --post-data="{ \"type\": \"${PIPELINE_TYPE}\",\"repository\": { \"name\": \"${REPOSITORY}\", \"hash\": \"${COMMIT}\", \"branch\": \"${BRANCH}\" }, \"author\": { \"name\": \"${AUTHOR_NAME}\", \"email\": \"${AUTHOR_EMAIL}\" }, \"pipeline\": \"${PIPELINE_NAME}\", \"projectName\": \"${PROJECT_NAME}\" }" \
    ${WEBHOOK_URL}
  kill ${PORT_FORWARD_PID}  

elif [ $LOCAL = $BASE ] || [ $REMOTE = $BASE ]; then
  git pull && git push
else
  echo "Diverged"
  exit 1
fi

