#!/bin/bash
# Lab: Deploying GKE Autopilot Clusters from Cloud Shell (GSP101)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Deploying GKE Autopilot Clusters from Cloud Shell (GSP101) ===${RESET}"

my_region=${REGION:-$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)}
if [ -z "$my_region" ]; then
    my_region=$(gcloud config get-value compute/region 2>/dev/null)
fi

if [ -z "$my_region" ]; then
    read -p "${BOLD}Enter REGION (e.g., us-central1): ${RESET}" my_region
fi

my_cluster="autopilot-cluster-1"

echo "${YELLOW}Target Region:${RESET} $my_region"
echo "${YELLOW}Cluster Name:${RESET} $my_cluster"

# Step 1: Create GKE Autopilot Cluster
echo "${GREEN}${BOLD}Step 1: Creating GKE Autopilot cluster '$my_cluster'... (may take 5-8 mins)${RESET}"
gcloud container clusters describe "$my_cluster" --region="$my_region" >/dev/null 2>&1 || \
gcloud container clusters create-auto "$my_cluster" --region="$my_region" --quiet

# Step 2: Get Credentials
echo "${GREEN}${BOLD}Step 2: Fetching cluster credentials...${RESET}"
gcloud container clusters get-credentials "$my_cluster" --region="$my_region"

# Step 3: Deploy Nginx
echo "${GREEN}${BOLD}Step 3: Creating deployment 'nginx-1'...${RESET}"
kubectl create deployment --image=nginx nginx-1 || true

# Wait for Nginx Pod to be running
echo "${YELLOW}Waiting for nginx-1 pod to transition to Running state...${RESET}"
while true; do
  STATUS=$(kubectl get pods -l app=nginx-1 --no-headers -o custom-columns=":status.phase" 2>/dev/null | grep -v Running || true)
  PODS=$(kubectl get pods -l app=nginx-1 --no-headers 2>/dev/null || true)
  if [[ -n "$PODS" && -z "$STATUS" ]]; then
    echo "${GREEN}Nginx-1 pod is running!${RESET}"
    break
  fi
  sleep 10
done

my_nginx_pod=$(kubectl get pods --selector=app=nginx-1 --no-headers -o custom-columns=":metadata.name" | head -n 1)

# Step 4: Create and copy test.html
echo "${GREEN}${BOLD}Step 4: Uploading custom HTML to pod '$my_nginx_pod'...${RESET}"
cat <<EOF > test.html
<header><title>This is title</title></header>
Hello world
EOF

kubectl cp test.html "$my_nginx_pod":/usr/share/nginx/html/test.html

# Step 5: Expose Pod via LoadBalancer
echo "${GREEN}${BOLD}Step 5: Exposing nginx pod on port 80 via LoadBalancer...${RESET}"
kubectl expose pod "$my_nginx_pod" --port=80 --type=LoadBalancer || true

# Step 6: Deploy new-nginx pod manifest
echo "${GREEN}${BOLD}Step 6: Applying new-nginx pod manifest...${RESET}"
cat <<'EOF' > new-nginx-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: new-nginx
  labels:
    name: new-nginx
spec:
  containers:
  - name: new-nginx
    image: nginx
    ports:
    - containerPort: 80
EOF

kubectl apply -f new-nginx-pod.yaml

echo "${YELLOW}Waiting for new-nginx pod to be Running...${RESET}"
while true; do
  PHASE=$(kubectl get pod new-nginx --no-headers -o custom-columns=":status.phase" 2>/dev/null || true)
  if [[ "$PHASE" == "Running" ]]; then
    echo "${GREEN}new-nginx pod is running!${RESET}"
    break
  fi
  sleep 10
done

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
