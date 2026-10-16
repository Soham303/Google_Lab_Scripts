#!/bin/bash
# Lab: Managing Deployments Using Kubernetes Engine (GSP053)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Managing Deployments Using Kubernetes Engine (GSP053) ===${RESET}"

ZONE=${ZONE:-$(gcloud config get-value compute/zone 2>/dev/null)}
if [ -z "$ZONE" ]; then
    ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
fi

if [ -z "$ZONE" ]; then
    read -p "${BOLD}Enter ZONE (e.g., us-central1-a): ${RESET}" ZONE
fi

echo "${YELLOW}Setting zone:${RESET} $ZONE"
gcloud config set compute/zone "$ZONE" --quiet

# Step 1: Copy lab files
echo "${GREEN}${BOLD}Step 1: Downloading deployment manifests...${RESET}"
gsutil -m cp -r gs://spls/gsp053/orchestrate-with-kubernetes .
cd orchestrate-with-kubernetes/kubernetes

# Step 2: Create GKE Cluster
echo "${GREEN}${BOLD}Step 2: Creating cluster 'bootcamp'...${RESET}"
gcloud container clusters describe bootcamp --zone="$ZONE" >/dev/null 2>&1 || \
gcloud container clusters create bootcamp \
  --zone="$ZONE" \
  --machine-type=e2-small \
  --num-nodes=3 \
  --scopes="https://www.googleapis.com/auth/projecthosting,storage-rw" \
  --quiet

gcloud container clusters get-credentials bootcamp --zone="$ZONE"

# Step 3: Auth deployment and service
echo "${GREEN}${BOLD}Step 3: Creating Auth deployment and service...${RESET}"
sed -i 's/image: "kelseyhightower\/auth:2.0.0"/image: "kelseyhightower\/auth:1.0.0"/' deployments/auth.yaml
kubectl apply -f deployments/auth.yaml
kubectl apply -f services/auth.yaml

# Step 4: Hello deployment and service
echo "${GREEN}${BOLD}Step 4: Creating Hello deployment and service...${RESET}"
kubectl apply -f deployments/hello.yaml
kubectl apply -f services/hello.yaml

# Step 5: Frontend TLS secret and ConfigMap
echo "${GREEN}${BOLD}Step 5: Creating TLS secrets and Frontend configmap...${RESET}"
kubectl create secret generic tls-certs --from-file=tls/ || true
kubectl create configmap nginx-frontend-conf --from-file=nginx/frontend.conf || true
kubectl apply -f deployments/frontend.yaml
kubectl apply -f services/frontend.yaml

# Step 6: Scale deployment
echo "${GREEN}${BOLD}Step 6: Scaling hello deployment to 5 replicas...${RESET}"
kubectl scale deployment hello --replicas=5
sleep 5
kubectl scale deployment hello --replicas=3

# Step 7: Rolling update and rollback
echo "${GREEN}${BOLD}Step 7: Executing rolling update and rollback...${RESET}"
kubectl set image deployment/hello hello=kelseyhightower/hello:2.0.0
kubectl rollout status deployment/hello || true
kubectl rollout undo deployment/hello
kubectl rollout status deployment/hello || true

# Step 8: Canary deployment
echo "${GREEN}${BOLD}Step 8: Creating canary deployment...${RESET}"
kubectl apply -f deployments/hello-canary.yaml

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
