#!/bin/bash
# Lab: Cloud SQL for MySQL: Qwik Start (GSP151)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Cloud SQL for MySQL: Qwik Start (GSP151) ===${RESET}"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REGION=${REGION:-$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)}
if [ -z "$REGION" ]; then
    ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
    [ -n "$ZONE" ] && REGION="${ZONE%-*}"
fi
if [ -z "$REGION" ]; then
    REGION=$(gcloud config get-value compute/region 2>/dev/null)
fi
if [ -z "$REGION" ]; then
    read -p "${BOLD}Enter REGION (e.g., us-central1): ${RESET}" REGION
fi

echo "${YELLOW}Project ID:${RESET} $PROJECT_ID"
echo "${YELLOW}Region:${RESET} $REGION"

# Step 1: Create Cloud SQL Instance
echo "${GREEN}${BOLD}Step 1: Creating Cloud SQL instance 'myinstance'... (takes ~3-5 mins)${RESET}"
gcloud sql instances describe myinstance >/dev/null 2>&1 || \
gcloud sql instances create myinstance \
    --database-version=MYSQL_8_0 \
    --tier=db-n1-standard-4 \
    --region="$REGION" \
    --root-password="password123" \
    --quiet

# Step 2: Create guestbook database
echo "${GREEN}${BOLD}Step 2: Creating database 'guestbook'...${RESET}"
gcloud sql databases describe guestbook --instance=myinstance >/dev/null 2>&1 || \
gcloud sql databases create guestbook --instance=myinstance --quiet

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
