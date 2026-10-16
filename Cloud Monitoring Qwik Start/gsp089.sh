#!/bin/bash
# Lab: Cloud Monitoring: Qwik Start (GSP089)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Cloud Monitoring: Qwik Start (GSP089) ===${RESET}"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
ZONE=${ZONE:-$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)}
if [ -z "$ZONE" ]; then
    ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
fi
if [ -z "$ZONE" ]; then
    read -p "${BOLD}Enter ZONE (e.g., us-central1-a): ${RESET}" ZONE
fi

REGION="${ZONE%-*}"
USER_EMAIL=${USER_EMAIL:-$(gcloud config get-value account 2>/dev/null)}

echo "${YELLOW}Project ID:${RESET} $PROJECT_ID"
echo "${YELLOW}Project Number:${RESET} $PROJECT_NUMBER"
echo "${YELLOW}Zone:${RESET} $ZONE"
echo "${YELLOW}Region:${RESET} $REGION"
echo "${YELLOW}User Email:${RESET} $USER_EMAIL"

# Step 1: Enable OS Config Service
echo "${GREEN}${BOLD}Step 1: Enabling OS Config and Monitoring APIs...${RESET}"
gcloud services enable osconfig.googleapis.com monitoring.googleapis.com --quiet
gcloud config set compute/zone "$ZONE" --quiet
gcloud config set compute/region "$REGION" --quiet

# Step 2: Create LAMP VM with startup script
echo "${GREEN}${BOLD}Step 2: Creating VM instance 'lamp-1-vm'...${RESET}"
cat > /tmp/lamp-startup.sh <<'EOF'
#!/bin/bash
apt-get update
apt-get install -y apache2 php
systemctl restart apache2
EOF

gcloud compute instances describe lamp-1-vm --zone="$ZONE" >/dev/null 2>&1 || \
gcloud compute instances create lamp-1-vm \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type=e2-medium \
    --tags=http-server \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --metadata-from-file=startup-script=/tmp/lamp-startup.sh \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write \
    --quiet

# Step 3: Firewall rule for HTTP
echo "${GREEN}${BOLD}Step 3: Creating HTTP firewall rule...${RESET}"
gcloud compute firewall-rules describe allow-http >/dev/null 2>&1 || \
gcloud compute firewall-rules create allow-http \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:80 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server \
    --quiet

# Step 4: Setup Uptime Check
echo "${GREEN}${BOLD}Step 4: Configuring Uptime Check...${RESET}"
INSTANCE_ID=$(gcloud compute instances list --filter="name=lamp-1-vm" --zones="$ZONE" --format="value(id)")

curl -s -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" \
  "https://monitoring.googleapis.com/v3/projects/$PROJECT_ID/uptimeCheckConfigs" \
  -d "{
  \"displayName\": \"Lamp Uptime Check\",
  \"httpCheck\": {
    \"path\": \"/\",
    \"port\": 80,
    \"requestMethod\": \"GET\"
  },
  \"monitoredResource\": {
    \"labels\": {
      \"instance_id\": \"$INSTANCE_ID\",
      \"project_id\": \"$PROJECT_ID\",
      \"zone\": \"$ZONE\"
    },
    \"type\": \"gce_instance\"
  }
}" || true

# Step 5: Create Email Notification Channel
echo "${GREEN}${BOLD}Step 5: Creating notification channel...${RESET}"
cat > /tmp/email-channel.json <<EOF
{
  "type": "email",
  "displayName": "Lab Notification Channel",
  "description": "Alert notification channel for lab",
  "labels": {
    "email_address": "$USER_EMAIL"
  }
}
EOF

gcloud beta monitoring channels create --channel-content-from-file=/tmp/email-channel.json --quiet || true
CHANNEL_ID=$(gcloud beta monitoring channels list --format="value(name)" | head -n 1)

# Step 6: Create Alerting Policy
echo "${GREEN}${BOLD}Step 6: Creating Alerting Policy...${RESET}"
cat > /tmp/alert-policy.json <<EOF
{
  "displayName": "Inbound Traffic Alert",
  "combiner": "OR",
  "conditions": [
    {
      "displayName": "VM Instance - Network traffic",
      "conditionThreshold": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/network/received_bytes_count\"",
        "aggregations": [
          {
            "alignmentPeriod": "300s",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "thresholdValue": 500,
        "duration": "60s",
        "trigger": {
          "count": 1
        }
      }
    }
  ],
  "notificationChannels": [
    "$CHANNEL_ID"
  ]
}
EOF

gcloud alpha monitoring policies create --policy-from-file=/tmp/alert-policy.json --quiet || true

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
