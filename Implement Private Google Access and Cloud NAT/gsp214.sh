#!/bin/bash
# Lab: Implement Private Google Access and Cloud NAT (GSP214)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Implement Private Google Access and Cloud NAT (GSP214) ===${RESET}"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
ZONE=${ZONE:-$(gcloud config get-value compute/zone 2>/dev/null)}
if [ -z "$ZONE" ]; then
    ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
fi

if [ -z "$ZONE" ]; then
    read -p "${BOLD}Enter ZONE (e.g., us-central1-c): ${RESET}" ZONE
fi

REGION="${ZONE%-*}"

echo "${YELLOW}Project ID:${RESET} $PROJECT_ID"
echo "${YELLOW}Zone:${RESET} $ZONE"
echo "${YELLOW}Region:${RESET} $REGION"

# Step 1: Create custom network and subnet
echo "${GREEN}${BOLD}Step 1: Creating 'privatenet' custom VPC and subnet...${RESET}"
gcloud compute networks describe privatenet >/dev/null 2>&1 || \
gcloud compute networks create privatenet --project="$PROJECT_ID" --subnet-mode=custom --mtu=1460 --bgp-routing-mode=regional --quiet

gcloud compute networks subnets describe privatenet-us --region="$REGION" >/dev/null 2>&1 || \
gcloud compute networks subnets create privatenet-us \
    --project="$PROJECT_ID" \
    --range=10.130.0.0/20 \
    --network=privatenet \
    --region="$REGION" \
    --quiet

# Step 2: Create firewall rule for IAP / SSH
echo "${GREEN}${BOLD}Step 2: Creating SSH firewall rule for Identity-Aware Proxy...${RESET}"
gcloud compute firewall-rules describe privatenet-allow-ssh >/dev/null 2>&1 || \
gcloud compute firewall-rules create privatenet-allow-ssh \
    --direction=INGRESS \
    --priority=1000 \
    --network=privatenet \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --quiet

# Step 3: Create vm-internal (no external IP)
echo "${GREEN}${BOLD}Step 3: Creating internal VM instance 'vm-internal'...${RESET}"
gcloud compute instances describe vm-internal --zone="$ZONE" >/dev/null 2>&1 || \
gcloud compute instances create vm-internal \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type=e2-medium \
    --network-interface=subnet=privatenet-us,no-address \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --quiet

# Step 4: Create Cloud Storage bucket & copy training asset
echo "${GREEN}${BOLD}Step 4: Creating Cloud Storage bucket and copying test assets...${RESET}"
gsutil mb -l "$REGION" "gs://$PROJECT_ID" || true
gcloud storage cp gs://cloud-training/gcpnet/private/access.svg "gs://$PROJECT_ID/" || true

# Step 5: Enable Private Google Access on subnet
echo "${GREEN}${BOLD}Step 5: Enabling Private Google Access on 'privatenet-us'...${RESET}"
gcloud compute networks subnets update privatenet-us \
    --region="$REGION" \
    --enable-private-ip-google-access \
    --quiet

# Step 6: Create Cloud Router & Cloud NAT
echo "${GREEN}${BOLD}Step 6: Setting up Cloud Router and Cloud NAT gateway...${RESET}"
gcloud compute routers describe nat-router --region="$REGION" >/dev/null 2>&1 || \
gcloud compute routers create nat-router --region="$REGION" --network=privatenet --quiet

gcloud compute routers nats describe nat-config --router=nat-router --region="$REGION" >/dev/null 2>&1 || \
gcloud compute routers nats create nat-config \
    --router=nat-router \
    --region="$REGION" \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges \
    --quiet

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
