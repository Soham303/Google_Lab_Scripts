#!/bin/bash
# Lab: A Tour of Google Cloud Hands-on Labs (GSP282)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: A Tour of Google Cloud Hands-on Labs (GSP282) ===${RESET}"

# Prompt for USER_2 if not provided
if [ -z "$USER_2" ]; then
    read -p "${BOLD}Enter Username 2 (e.g., student-xx-xxxx@qwiklabs.net): ${RESET}" USER_2
fi

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
echo "${YELLOW}Current Project:${RESET} $PROJECT_ID"
echo "${YELLOW}Username 2:${RESET} $USER_2"

# Step 1: Add IAM policy binding
echo "${GREEN}${BOLD}Step 1: Adding IAM policy binding for Username 2...${RESET}"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="user:$USER_2" \
    --role="roles/viewer" --quiet

# Step 2: Enable Dialogflow API
echo "${GREEN}${BOLD}Step 2: Enabling Dialogflow API...${RESET}"
gcloud services enable dialogflow.googleapis.com --quiet

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
