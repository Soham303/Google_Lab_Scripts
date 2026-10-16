#!/bin/bash
# Lab: Creating a Virtual Machine (GSP001)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Creating a Virtual Machine (GSP001) ===${RESET}"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
ZONE=${ZONE:-$(gcloud config get-value compute/zone 2>/dev/null)}
if [ -z "$ZONE" ]; then
    ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
fi

if [ -z "$ZONE" ]; then
    read -p "${BOLD}Enter ZONE (e.g., us-central1-a): ${RESET}" ZONE
fi

echo "${YELLOW}Project ID:${RESET} $PROJECT_ID"
echo "${YELLOW}Zone:${RESET} $ZONE"

# Step 1: Create instance gcelab
echo "${GREEN}${BOLD}Step 1: Creating VM instance 'gcelab'...${RESET}"
gcloud compute instances create gcelab \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type=e2-medium \
    --tags=http-server,allow-http \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --metadata=startup-script='#! /bin/bash
apt-get update
apt-get install -y nginx
systemctl start nginx' \
    --quiet

# Step 2: Create firewall rule
echo "${GREEN}${BOLD}Step 2: Creating firewall rule 'allow-http'...${RESET}"
gcloud compute firewall-rules describe allow-http >/dev/null 2>&1 || \
gcloud compute firewall-rules create allow-http \
    --network=default \
    --allow=tcp:80 \
    --target-tags=http-server,allow-http \
    --quiet

# Step 3: Create second instance gcelab2
echo "${GREEN}${BOLD}Step 3: Creating VM instance 'gcelab2'...${RESET}"
gcloud compute instances describe gcelab2 --zone="$ZONE" >/dev/null 2>&1 || \
gcloud compute instances create gcelab2 \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type=e2-medium \
    --quiet

# Step 4: Verify Nginx is active on gcelab via SSH
echo "${GREEN}${BOLD}Step 4: Verifying Nginx installation on 'gcelab'...${RESET}"
for i in $(seq 1 12); do
    if gcloud compute ssh gcelab --zone="$ZONE" --quiet --command="systemctl is-active nginx" 2>/dev/null | grep -q "active"; then
        echo "${GREEN}Nginx is up and running!${RESET}"
        break
    fi
    echo "Waiting for Nginx to initialize ($i/12)..."
    sleep 5
done

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
