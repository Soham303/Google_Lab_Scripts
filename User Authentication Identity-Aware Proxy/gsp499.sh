#!/bin/bash
# Lab: User Authentication: Identity-Aware Proxy (GSP499)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: User Authentication: Identity-Aware Proxy (GSP499) ===${RESET}"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$REGION" ]; then
    DEFAULT_R=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)
    DEFAULT_R=${DEFAULT_R:-$(gcloud config get-value compute/region 2>/dev/null)}
    DEFAULT_R=${DEFAULT_R:-us-central}
    read -p "Enter App Engine Region (default: $DEFAULT_R): " input_r
    REGION=${input_r:-$DEFAULT_R}
fi

echo "${YELLOW}Project ID:${RESET} $PROJECT_ID"
echo "${YELLOW}Region:${RESET} $REGION"

# Step 1: Enable APIs
echo "${GREEN}${BOLD}Step 1: Enabling IAP and App Engine APIs...${RESET}"
gcloud services enable iap.googleapis.com appengine.googleapis.com --quiet

# Step 2: Download and unpack lab archive
echo "${GREEN}${BOLD}Step 2: Downloading sample application package...${RESET}"
gsutil cp gs://spls/gsp499/user-authentication-with-iap.zip .
unzip -q -o user-authentication-with-iap.zip

# Step 3: Initialize App Engine if not already initialized
if ! gcloud app describe >/dev/null 2>&1; then
    echo "${GREEN}${BOLD}Step 3: Initializing App Engine application...${RESET}"
    gcloud app create --region="$REGION" --quiet || gcloud app create --region="us-central" --quiet
fi

# Step 4: Deploy 1-HelloWorld
echo "${GREEN}${BOLD}Step 4: Deploying 1-HelloWorld...${RESET}"
cd user-authentication-with-iap/1-HelloWorld
sed -i 's/python37/python39/g' app.yaml
gcloud app deploy --quiet

# Step 5: Deploy 2-HelloUser
echo "${GREEN}${BOLD}Step 5: Deploying 2-HelloUser...${RESET}"
cd ../2-HelloUser
sed -i 's/python37/python39/g' app.yaml
gcloud app deploy --quiet

# Step 6: Deploy 3-HelloVerifiedUser
echo "${GREEN}${BOLD}Step 6: Deploying 3-HelloVerifiedUser...${RESET}"
cd ../3-HelloVerifiedUser
sed -i 's/python37/python39/g' app.yaml
gcloud app deploy --quiet

cd ../..

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! App deployments successfully completed.${RESET}"
echo "${YELLOW}Note: If the lab requires turning on the IAP toggle in the Cloud Console:${RESET}"
echo "1. Go to: https://console.cloud.google.com/security/iap?project=$PROJECT_ID"
echo "2. Toggle IAP ON for your App Engine app."
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
