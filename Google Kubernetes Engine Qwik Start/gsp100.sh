#!/bin/bash
# Lab: Google Kubernetes Engine: Qwik Start (GSP100)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Google Kubernetes Engine: Qwik Start (GSP100) ===${RESET}"

ZONE=${ZONE:-$(gcloud config get-value compute/zone 2>/dev/null)}
if [ -z "$ZONE" ]; then
    ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
fi

if [ -z "$ZONE" ]; then
    read -p "${BOLD}Enter ZONE (e.g., us-central1-a): ${RESET}" ZONE
fi

echo "${YELLOW}Configuring zone:${RESET} $ZONE"
gcloud config set compute/zone "$ZONE" --quiet

# Step 1: Create GKE Cluster
echo "${GREEN}${BOLD}Step 1: Creating Kubernetes cluster 'lab-cluster'...${RESET}"
gcloud container clusters describe lab-cluster --zone="$ZONE" >/dev/null 2>&1 || \
gcloud container clusters create lab-cluster \
    --machine-type=e2-medium \
    --zone="$ZONE" \
    --num-nodes=3 \
    --quiet

# Step 2: Get Cluster Credentials
echo "${GREEN}${BOLD}Step 2: Fetching cluster credentials...${RESET}"
gcloud container clusters get-credentials lab-cluster --zone="$ZONE"

# Step 3: Create hello-server deployment
echo "${GREEN}${BOLD}Step 3: Creating deployment 'hello-server'...${RESET}"
kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:1.0 || true

# Step 4: Expose deployment
echo "${GREEN}${BOLD}Step 4: Exposing deployment via LoadBalancer...${RESET}"
kubectl expose deployment hello-server --type=LoadBalancer --port 8080 || true

echo "${YELLOW}Waiting 60s for external LoadBalancer IP provisioning...${RESET}"
sleep 60

kubectl get service hello-server

# Step 5: Delete Cluster (Required by the lab to complete final check)
echo "${GREEN}${BOLD}Step 5: Deleting cluster 'lab-cluster' (final lab requirement)...${RESET}"
gcloud container clusters delete lab-cluster --zone="$ZONE" --quiet

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
