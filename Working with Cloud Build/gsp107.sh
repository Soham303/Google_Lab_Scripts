#!/bin/bash
# Lab: Working with Cloud Build (GSP107)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Working with Cloud Build (GSP107) ===${RESET}"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REGION=${REGION:-$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)}
if [ -z "$REGION" ]; then
    REGION=$(gcloud config get-value compute/region 2>/dev/null)
fi
if [ -z "$REGION" ]; then
    read -p "${BOLD}Enter REGION (e.g., us-central1): ${RESET}" REGION
fi

echo "${YELLOW}Project ID:${RESET} $PROJECT_ID"
echo "${YELLOW}Region:${RESET} $REGION"

# Step 1: Enable Cloud Build and Artifact Registry
echo "${GREEN}${BOLD}Step 1: Enabling Cloud Build & Artifact Registry APIs...${RESET}"
gcloud services enable cloudbuild.googleapis.com artifactregistry.googleapis.com --quiet

# Step 2: Create sample application files
echo "${GREEN}${BOLD}Step 2: Creating quickstart.sh and Dockerfile...${RESET}"
cat <<'EOF' > quickstart.sh
#!/bin/sh
echo "Hello, world! The time is $(date)."
EOF
chmod +x quickstart.sh

cat <<'EOF' > Dockerfile
FROM alpine
COPY quickstart.sh /
CMD ["/quickstart.sh"]
EOF

# Step 3: Create Artifact Registry Repository
echo "${GREEN}${BOLD}Step 3: Creating Docker repository 'quickstart-docker-repo'...${RESET}"
gcloud artifacts repositories describe quickstart-docker-repo --location="$REGION" >/dev/null 2>&1 || \
gcloud artifacts repositories create quickstart-docker-repo \
    --repository-format=docker \
    --location="$REGION" \
    --description="Docker repository for quickstart" \
    --quiet

# Step 4: Submit initial build
echo "${GREEN}${BOLD}Step 4: Submitting container build to Cloud Build...${RESET}"
IMAGE_URI="$REGION-docker.pkg.dev/$PROJECT_ID/quickstart-docker-repo/quickstart-image:tag1"
gcloud builds submit --tag "$IMAGE_URI"

# Step 5: Build with cloudbuild.yaml
echo "${GREEN}${BOLD}Step 5: Submitting build using cloudbuild.yaml config...${RESET}"
cat <<EOF > cloudbuild.yaml
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: [ 'build', '-t', '$IMAGE_URI', '.' ]
images:
- '$IMAGE_URI'
EOF

gcloud builds submit --config cloudbuild.yaml

# Step 6: Test multi-step build
echo "${GREEN}${BOLD}Step 6: Running multi-step build verification...${RESET}"
cat <<'EOF' > quickstart.sh
#!/bin/sh
if [ -z "$1" ]; then
    echo "Hello, world! The time is $(date)."
    exit 0
else
    exit 1
fi
EOF

cat <<EOF > cloudbuild2.yaml
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: [ 'build', '-t', '$IMAGE_URI', '.' ]
- name: '$IMAGE_URI'
  args: ['fail']
images:
- '$IMAGE_URI'
EOF

gcloud builds submit --config cloudbuild2.yaml || true

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
