#!/bin/bash
# Lab: Multiple VPC Networks (GSP211)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Multiple VPC Networks (GSP211) ===${RESET}"

# Attempt to discover zone and region information from pre-existing lab VMs
ZONE_1=$(gcloud compute instances list --filter="name=mynet-vm-1" --format='csv[no-heading](zone)' 2>/dev/null | head -n 1)
ZONE_2=$(gcloud compute instances list --filter="name=mynet-vm-2" --format='csv[no-heading](zone)' 2>/dev/null | head -n 1)

if [ -z "$ZONE_1" ]; then
    ZONE_1=${Z1:-$(gcloud config get-value compute/zone 2>/dev/null)}
fi

if [ -z "$ZONE_1" ]; then
    read -p "${BOLD}Enter ZONE 1 (e.g., us-east1-b): ${RESET}" ZONE_1
fi

if [ -z "$ZONE_2" ]; then
    read -p "${BOLD}Enter ZONE 2 (e.g., europe-west1-b): ${RESET}" ZONE_2
fi

REGION_1=$(echo "$ZONE_1" | cut -d '-' -f 1-2)
REGION_2=$(echo "$ZONE_2" | cut -d '-' -f 1-2)

echo "${YELLOW}Zone 1:${RESET} $ZONE_1 (${YELLOW}Region 1:${RESET} $REGION_1)"
echo "${YELLOW}Zone 2:${RESET} $ZONE_2 (${YELLOW}Region 2:${RESET} $REGION_2)"

# Step 1: Create managementnet and subnet
echo "${GREEN}${BOLD}Step 1: Creating 'managementnet' custom VPC and subnet...${RESET}"
gcloud compute networks describe managementnet >/dev/null 2>&1 || \
gcloud compute networks create managementnet --subnet-mode=custom --quiet

gcloud compute networks subnets describe managementsubnet-1 --region="$REGION_1" >/dev/null 2>&1 || \
gcloud compute networks subnets create managementsubnet-1 \
    --network=managementnet \
    --region="$REGION_1" \
    --range=10.130.0.0/20 \
    --quiet

# Step 2: Create privatenet and subnets
echo "${GREEN}${BOLD}Step 2: Creating 'privatenet' custom VPC and subnets...${RESET}"
gcloud compute networks describe privatenet >/dev/null 2>&1 || \
gcloud compute networks create privatenet --subnet-mode=custom --quiet

gcloud compute networks subnets describe privatesubnet-1 --region="$REGION_1" >/dev/null 2>&1 || \
gcloud compute networks subnets create privatesubnet-1 \
    --network=privatenet \
    --region="$REGION_1" \
    --range=172.16.0.0/24 \
    --quiet

gcloud compute networks subnets describe privatesubnet-2 --region="$REGION_2" >/dev/null 2>&1 || \
gcloud compute networks subnets create privatesubnet-2 \
    --network=privatenet \
    --region="$REGION_2" \
    --range=172.20.0.0/20 \
    --quiet

# Step 3: Create firewall rules
echo "${GREEN}${BOLD}Step 3: Creating firewall rules for ICMP, SSH, and RDP...${RESET}"
gcloud compute firewall-rules describe managementnet-allow-icmp-ssh-rdp >/dev/null 2>&1 || \
gcloud compute firewall-rules create managementnet-allow-icmp-ssh-rdp \
    --direction=INGRESS \
    --priority=1000 \
    --network=managementnet \
    --action=ALLOW \
    --rules=icmp,tcp:22,tcp:3389 \
    --source-ranges=0.0.0.0/0 \
    --quiet

gcloud compute firewall-rules describe privatenet-allow-icmp-ssh-rdp >/dev/null 2>&1 || \
gcloud compute firewall-rules create privatenet-allow-icmp-ssh-rdp \
    --direction=INGRESS \
    --priority=1000 \
    --network=privatenet \
    --action=ALLOW \
    --rules=icmp,tcp:22,tcp:3389 \
    --source-ranges=0.0.0.0/0 \
    --quiet

# Step 4: Create VM instances in managementnet and privatenet
echo "${GREEN}${BOLD}Step 4: Provisioning VM instances...${RESET}"
gcloud compute instances describe managementnet-vm-1 --zone="$ZONE_1" >/dev/null 2>&1 || \
gcloud compute instances create managementnet-vm-1 \
    --zone="$ZONE_1" \
    --machine-type=e2-micro \
    --subnet=managementsubnet-1 \
    --quiet

gcloud compute instances describe privatenet-vm-1 --zone="$ZONE_1" >/dev/null 2>&1 || \
gcloud compute instances create privatenet-vm-1 \
    --zone="$ZONE_1" \
    --machine-type=e2-micro \
    --subnet=privatesubnet-1 \
    --quiet

# Step 5: Create multi-NIC vm-appliance
echo "${GREEN}${BOLD}Step 5: Creating multi-NIC appliance 'vm-appliance'...${RESET}"
gcloud compute instances describe vm-appliance --zone="$ZONE_1" >/dev/null 2>&1 || \
gcloud compute instances create vm-appliance \
    --zone="$ZONE_1" \
    --machine-type=e2-standard-4 \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=privatesubnet-1 \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=managementsubnet-1 \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=mynetwork \
    --quiet

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
