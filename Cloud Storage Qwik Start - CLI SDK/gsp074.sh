#!/bin/bash
# Lab: Cloud Storage: Qwik Start - CLI/SDK (GSP074)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Cloud Storage: Qwik Start - CLI/SDK (GSP074) ===${RESET}"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REGION=${REGION:-$(gcloud config get-value compute/region 2>/dev/null)}
[ -z "$REGION" ] && REGION="us-east1"

echo "${YELLOW}Project ID:${RESET} $PROJECT_ID"
echo "${YELLOW}Region:${RESET} $REGION"

# Step 1: Create Cloud Storage Bucket
echo "${GREEN}${BOLD}Step 1: Creating bucket gs://$PROJECT_ID...${RESET}"
gsutil mb -l "$REGION" "gs://$PROJECT_ID" || true

# Step 2: Download sample image
echo "${GREEN}${BOLD}Step 2: Downloading Ada Lovelace image...${RESET}"
curl -s -L "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Ada_Lovelace_portrait.jpg/800px-Ada_Lovelace_portrait.jpg" --output ada.jpg

# Step 3: Copy image into bucket
echo "${GREEN}${BOLD}Step 3: Uploading ada.jpg to bucket...${RESET}"
gsutil cp ada.jpg "gs://$PROJECT_ID/"

# Step 4: Copy image back from bucket
echo "${GREEN}${BOLD}Step 4: Copying image back from bucket...${RESET}"
gsutil cp "gs://$PROJECT_ID/ada.jpg" ./ada_downloaded.jpg

# Step 5: Copy image to folder within bucket
echo "${GREEN}${BOLD}Step 5: Copying image into image-folder/ in bucket...${RESET}"
gsutil cp "gs://$PROJECT_ID/ada.jpg" "gs://$PROJECT_ID/image-folder/"

# Step 6: Make object publicly readable
echo "${GREEN}${BOLD}Step 6: Setting public read ACL...${RESET}"
gsutil acl ch -u AllUsers:R "gs://$PROJECT_ID/ada.jpg"

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
