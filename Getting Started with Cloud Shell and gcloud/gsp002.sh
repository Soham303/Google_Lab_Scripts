#!/bin/bash
# Lab: Getting Started with Cloud Shell and gcloud (GSP002)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Getting Started with Cloud Shell and gcloud (GSP002) ===${RESET}"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
ZONE=${ZONE:-$(gcloud config get-value compute/zone 2>/dev/null)}
if [ -z "$ZONE" ]; then
    ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
fi

if [ -z "$ZONE" ]; then
    read -p "${BOLD}Enter ZONE (e.g., us-central1-a): ${RESET}" ZONE
fi

REGION="${ZONE%-*}"
echo "${YELLOW}Project ID:${RESET} $PROJECT_ID"
echo "${YELLOW}Region:${RESET} $REGION"
echo "${YELLOW}Zone:${RESET} $ZONE"

# Step 1: Configure region and zone
echo "${GREEN}${BOLD}Step 1: Setting default compute region and zone...${RESET}"
gcloud config set compute/region "$REGION" --quiet
gcloud config set compute/zone "$ZONE" --quiet

# Step 2: Create instance gcelab2
echo "${GREEN}${BOLD}Step 2: Creating VM instance 'gcelab2'...${RESET}"
gcloud compute instances describe gcelab2 --zone="$ZONE" >/dev/null 2>&1 || \
gcloud compute instances create gcelab2 \
    --machine-type=e2-medium \
    --zone="$ZONE" \
    --tags=http-server,https-server \
    --quiet

# Step 3: Create firewall rule
echo "${GREEN}${BOLD}Step 3: Creating firewall rule 'default-allow-http'...${RESET}"
gcloud compute firewall-rules describe default-allow-http >/dev/null 2>&1 || \
gcloud compute firewall-rules create default-allow-http \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server \
    --quiet

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
