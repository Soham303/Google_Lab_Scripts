#!/bin/bash
# Lab: Cloud IAM: Qwik Start (GSP064)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Cloud IAM: Qwik Start (GSP064) ===${RESET}"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$USER_2" ]; then
    read -p "${BOLD}Enter Username 2 (e.g., student-xx-xxxx@qwiklabs.net): ${RESET}" USER_2
fi

echo "${YELLOW}Project ID:${RESET} $PROJECT_ID"
echo "${YELLOW}Username 2:${RESET} $USER_2"

# Step 1: Create Cloud Storage bucket
echo "${GREEN}${BOLD}Step 1: Creating Cloud Storage bucket...${RESET}"
gsutil mb -l us -b on "gs://$PROJECT_ID" || true

# Step 2: Upload sample object
echo "${GREEN}${BOLD}Step 2: Uploading sample file to bucket...${RESET}"
echo "Cloud IAM Lab Verification File" > sample.txt
gsutil cp sample.txt "gs://$PROJECT_ID/"

# Step 3: Remove viewer role for Username 2
echo "${GREEN}${BOLD}Step 3: Removing viewer role from Username 2...${RESET}"
gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
  --member="user:$USER_2" \
  --role="roles/viewer" --quiet || true

# Step 4: Add Storage Object Viewer role for Username 2
echo "${GREEN}${BOLD}Step 4: Granting Storage Object Viewer role to Username 2...${RESET}"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:$USER_2" \
  --role="roles/storage.objectViewer" --quiet

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
