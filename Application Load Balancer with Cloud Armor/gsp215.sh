#!/bin/bash
# Lab: Application Load Balancer with Cloud Armor (GSP215)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Application Load Balancer with Cloud Armor (GSP215) ===${RESET}"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REGION1=${REGION1:-$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)}
if [ -z "$REGION1" ]; then
    REGION1=$(gcloud config get-value compute/region 2>/dev/null)
fi
if [ -z "$REGION1" ]; then
    REGION1="us-central1"
fi

if [ -z "$REGION2" ]; then
    read -p "${BOLD}Enter REGION2 (e.g., europe-west1): ${RESET}" REGION2
fi

if [ -z "$VM_ZONE" ]; then
    read -p "${BOLD}Enter VM_ZONE (e.g., us-central1-c): ${RESET}" VM_ZONE
fi

echo "${YELLOW}Project ID:${RESET} $PROJECT_ID"
echo "${YELLOW}Region 1:${RESET} $REGION1"
echo "${YELLOW}Region 2:${RESET} $REGION2"
echo "${YELLOW}VM Zone:${RESET} $VM_ZONE"

# Step 1: Firewall rules
echo "${GREEN}${BOLD}Step 1: Creating firewall rules for HTTP and Health Checks...${RESET}"
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

gcloud compute firewall-rules describe default-allow-health-check >/dev/null 2>&1 || \
gcloud compute firewall-rules create default-allow-health-check \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=http-server \
    --quiet

# Step 2: Instance Templates
echo "${GREEN}${BOLD}Step 2: Creating instance templates for $REGION1 and $REGION2...${RESET}"
gcloud compute instance-templates describe "$REGION1-template" >/dev/null 2>&1 || \
gcloud compute instance-templates create "$REGION1-template" \
    --machine-type=e2-micro \
    --network-interface=network-tier=PREMIUM,subnet=default \
    --metadata=startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh \
    --region="$REGION1" \
    --tags=http-server,https-server \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --quiet

gcloud compute instance-templates describe "$REGION2-template" >/dev/null 2>&1 || \
gcloud compute instance-templates create "$REGION2-template" \
    --machine-type=e2-micro \
    --network-interface=network-tier=PREMIUM,subnet=default \
    --metadata=startup-script-url=gs://cloud-training/gcpnet/httplb/startup.sh \
    --region="$REGION2" \
    --tags=http-server,https-server \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --quiet

# Step 3: Managed Instance Groups & Autoscaling
echo "${GREEN}${BOLD}Step 3: Creating MIGs and autoscaling policies...${RESET}"
gcloud compute instance-groups managed describe "$REGION1-mig" --region="$REGION1" >/dev/null 2>&1 || \
gcloud compute instance-groups managed create "$REGION1-mig" \
    --base-instance-name="$REGION1-mig" \
    --size=1 \
    --template="$REGION1-template" \
    --region="$REGION1" \
    --quiet

gcloud compute instance-groups managed set-autoscaling "$REGION1-mig" \
    --region="$REGION1" \
    --cool-down-period=45 \
    --max-num-replicas=2 \
    --min-num-replicas=1 \
    --target-cpu-utilization=0.8 \
    --quiet

gcloud compute instance-groups managed set-named-ports "$REGION1-mig" \
    --region="$REGION1" \
    --named-ports=http:80 \
    --quiet

gcloud compute instance-groups managed describe "$REGION2-mig" --region="$REGION2" >/dev/null 2>&1 || \
gcloud compute instance-groups managed create "$REGION2-mig" \
    --base-instance-name="$REGION2-mig" \
    --size=1 \
    --template="$REGION2-template" \
    --region="$REGION2" \
    --quiet

gcloud compute instance-groups managed set-autoscaling "$REGION2-mig" \
    --region="$REGION2" \
    --cool-down-period=45 \
    --max-num-replicas=2 \
    --min-num-replicas=1 \
    --target-cpu-utilization=0.8 \
    --quiet

gcloud compute instance-groups managed set-named-ports "$REGION2-mig" \
    --region="$REGION2" \
    --named-ports=http:80 \
    --quiet

# Step 4: Health Check & Backend Service
echo "${GREEN}${BOLD}Step 4: Configuring Health Check and Backend Service...${RESET}"
gcloud compute health-checks describe http-health-check >/dev/null 2>&1 || \
gcloud compute health-checks create tcp http-health-check --port=80 --quiet

gcloud compute backend-services describe http-backend --global >/dev/null 2>&1 || \
gcloud compute backend-services create http-backend \
    --protocol=HTTP \
    --port-name=http \
    --health-checks=http-health-check \
    --global \
    --enable-cdn \
    --quiet

gcloud compute backend-services add-backend http-backend \
    --instance-group="$REGION1-mig" \
    --instance-group-region="$REGION1" \
    --balancing-mode=RATE \
    --max-rate-per-instance=50 \
    --global \
    --quiet || true

gcloud compute backend-services add-backend http-backend \
    --instance-group="$REGION2-mig" \
    --instance-group-region="$REGION2" \
    --balancing-mode=UTILIZATION \
    --max-utilization=0.8 \
    --global \
    --quiet || true

# Step 5: URL Map, Target Proxy & Forwarding Rules
echo "${GREEN}${BOLD}Step 5: Configuring Load Balancer Frontend...${RESET}"
gcloud compute url-maps describe http-lb >/dev/null 2>&1 || \
gcloud compute url-maps create http-lb --default-service=http-backend --quiet

gcloud compute target-http-proxies describe http-lb-target-proxy >/dev/null 2>&1 || \
gcloud compute target-http-proxies create http-lb-target-proxy --url-map=http-lb --quiet

gcloud compute forwarding-rules describe http-lb-forwarding-rule --global >/dev/null 2>&1 || \
gcloud compute forwarding-rules create http-lb-forwarding-rule \
    --global \
    --target-http-proxy=http-lb-target-proxy \
    --ports=80 \
    --network-tier=PREMIUM \
    --quiet

# Step 6: Create siege-vm
echo "${GREEN}${BOLD}Step 6: Provisioning 'siege-vm' for stress testing...${RESET}"
gcloud compute instances describe siege-vm --zone="$VM_ZONE" >/dev/null 2>&1 || \
gcloud compute instances create siege-vm \
    --zone="$VM_ZONE" \
    --machine-type=e2-medium \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --quiet

EXTERNAL_IP=$(gcloud compute instances describe siege-vm --zone="$VM_ZONE" --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
echo "${YELLOW}Siege VM NAT IP:${RESET} $EXTERNAL_IP"

# Step 7: Create Cloud Armor Security Policy
echo "${GREEN}${BOLD}Step 7: Creating Cloud Armor denylist policy...${RESET}"
gcloud compute security-policies describe denylist-siege >/dev/null 2>&1 || \
gcloud compute security-policies create denylist-siege --description="Denylist siege-vm IP" --quiet

gcloud compute security-policies rules describe 1000 --security-policy=denylist-siege >/dev/null 2>&1 || \
gcloud compute security-policies rules create 1000 \
    --security-policy=denylist-siege \
    --expression="inIpRange(origin.ip, '$EXTERNAL_IP/32')" \
    --action="deny-403" \
    --description="Block siege-vm" \
    --quiet

# Step 8: Attach Security Policy to Backend Service
echo "${GREEN}${BOLD}Step 8: Attaching Cloud Armor policy to http-backend...${RESET}"
gcloud compute backend-services update http-backend \
    --security-policy=denylist-siege \
    --global \
    --quiet

# Step 9: Run siege test
echo "${GREEN}${BOLD}Step 9: Testing traffic blocking from siege-vm...${RESET}"
LB_IP=$(gcloud compute forwarding-rules describe http-lb-forwarding-rule --global --format="value(IPAddress)")
echo "${YELLOW}Load Balancer IP:${RESET} $LB_IP"

for i in $(seq 1 10); do
    if gcloud compute ssh siege-vm --zone="$VM_ZONE" --quiet --command="sudo apt-get update && sudo apt-get install -y siege && siege -c 50 -t 30s http://$LB_IP" 2>/dev/null; then
        break
    fi
    sleep 10
done

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
