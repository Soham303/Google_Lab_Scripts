#!/bin/bash
# Lab: Automating the Deployment of Infrastructure Using Terraform (GSP075)

set -e

BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

echo "${CYAN}${BOLD}=== Starting Lab: Automating Infrastructure on Google Cloud with Terraform (GSP075) ===${RESET}"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
ZONE_1=${ZONE_1:-$(gcloud config get-value compute/zone 2>/dev/null)}
if [ -z "$ZONE_1" ]; then
    ZONE_1="us-central1-a"
fi
ZONE_2=${ZONE_2:-"europe-west1-d"}

echo "${YELLOW}Project ID:${RESET} $PROJECT_ID"
echo "${YELLOW}US Zone:${RESET} $ZONE_1"
echo "${YELLOW}EU Zone:${RESET} $ZONE_2"

mkdir -p tfinfra/instance
cd tfinfra

# Step 1: Create Terraform configuration files
echo "${GREEN}${BOLD}Step 1: Generating Terraform provider and network manifests...${RESET}"

cat <<'EOF' > provider.tf
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}
provider "google" {}
EOF

cat <<'EOF' > variables.tf
variable "instance_name" {}
variable "instance_zone" {}
variable "instance_type" {
  default = "e2-micro"
}
variable "instance_network" {}
EOF

cat <<EOF > mynetwork.tf
# Create the mynetwork network
resource "google_compute_network" "mynetwork" {
  name                    = "mynetwork"
  auto_create_subnetworks = true
}

# Create a firewall rule to allow HTTP, SSH, RDP and ICMP traffic on mynetwork
resource "google_compute_firewall" "mynetwork-allow-http-ssh-rdp-icmp" {
  name    = "mynetwork-allow-http-ssh-rdp-icmp"
  network = google_compute_network.mynetwork.self_link
  source_ranges = [
    "0.0.0.0/0"
  ]

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "3389"]
  }

  allow {
    protocol = "icmp"
  }
}

# Create the mynet-us-vm instance
module "mynet-us-vm" {
  source              = "./instance"
  instance_name       = "mynet-us-vm"
  instance_zone       = "$ZONE_1"
  instance_subnetwork = google_compute_network.mynetwork.self_link
}

# Create the mynet-eu-vm instance
module "mynet-eu-vm" {
  source              = "./instance"
  instance_name       = "mynet-eu-vm"
  instance_zone       = "$ZONE_2"
  instance_subnetwork = google_compute_network.mynetwork.self_link
}
EOF

cat <<'EOF' > instance/main.tf
variable "instance_name" {}
variable "instance_zone" {}

variable "instance_type" {
  default = "e2-micro"
}

variable "instance_subnetwork" {}

resource "google_compute_instance" "vm_instance" {
  name         = var.instance_name
  zone         = var.instance_zone
  machine_type = var.instance_type

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork = var.instance_subnetwork

    access_config {
      # Allocate a one-to-one NAT IP to the instance
    }
  }
}
EOF

# Step 2: Initialize Terraform
echo "${GREEN}${BOLD}Step 2: Initializing and formatting Terraform...${RESET}"
terraform init -upgrade
terraform fmt

# Step 3: Apply Terraform configuration
echo "${GREEN}${BOLD}Step 3: Applying Terraform infrastructure plan...${RESET}"
terraform apply \
  -var="instance_name=mynet-us-vm" \
  -var="instance_network=mynetwork" \
  -var="instance_zone=$ZONE_1" \
  --auto-approve

echo
echo "${GREEN}${BOLD}==================================================${RESET}"
echo "${GREEN}${BOLD}ALL DONE! Lab tasks successfully completed.${RESET}"
echo "${GREEN}${BOLD}Click 'Check my progress' on each task in Google Skills Boost.${RESET}"
echo "${GREEN}${BOLD}==================================================${RESET}"
