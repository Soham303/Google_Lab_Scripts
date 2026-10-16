#!/bin/bash
# GSP345 - Build Infrastructure with Terraform on Google Cloud: Challenge Lab
# Does Tasks 1-7 in order, pausing after each checkpoint so you can click "Check my progress".
# Run inside tmux:  tmux new -s lab   then   bash gsp345_v3.sh 2>&1 | tee gsp.log
# Skip the pauses with:  AUTO=1 bash gsp345_v3.sh

PROJECT=${PROJECT:-$(gcloud config get-value project 2>/dev/null)}
echo "Current Project: $PROJECT"

# Dynamic parameter inputs (uses env vars if set, otherwise prompts interactively)
if [ -z "$BUCKET" ]; then
  read -p "Enter Bucket Name (from lab prompt, e.g. tf-bucket-761677): " BUCKET
fi

if [ -z "$THIRD" ]; then
  read -p "Enter Third Instance Name (from lab prompt, e.g. tf-instance-703911): " THIRD
fi

if [ -z "$VPC" ]; then
  read -p "Enter VPC Name (from lab prompt, e.g. tf-vpc-470307): " VPC
fi

ZONE=${ZONE:-$(gcloud config get-value compute/zone 2>/dev/null)}
ZONE=${ZONE:-europe-west4-c}
REGION=${REGION:-${ZONE%-*}}

WORK=$HOME/tf-challenge
export GOOGLE_PROJECT=$PROJECT GOOGLE_CLOUD_PROJECT=$PROJECT TF_IN_AUTOMATION=1
export PATH=$HOME/bin:$PATH
 
say(){ echo; echo "=== $(date +%T) $* ==="; }
retry(){ for i in 1 2 3; do "$@" && return 0; echo "  (attempt $i failed, retrying in 10s)"; sleep 10; done; echo "FAILED: $*"; return 1; }
must(){ retry "$@" || { echo "STOPPING: step failed, see error above."; exit 1; }; }
pause(){
  [ "${AUTO:-0}" = "1" ] && return
  echo; echo ">>> CHECKPOINT: now click 'Check my progress' for: $1"
  read -r -p ">>> Press Enter to continue to the next task... " _ </dev/tty
}
 
gcloud services enable compute.googleapis.com storage.googleapis.com >/dev/null 2>&1
 
say "Install Terraform"
# Cloud Shell ships a STUB named terraform that only prints install help, so check for the real one.
have_tf(){ terraform version 2>/dev/null | grep -q '^Terraform v'; }
if ! have_tf; then
  echo "Real Terraform not found (only the Cloud Shell stub). Downloading binary..."
  mkdir -p ~/bin
  must curl -fsSL -o /tmp/tf.zip https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
  unzip -o /tmp/tf.zip -d ~/bin >/dev/null 2>&1 || python3 -c "import zipfile,os;zipfile.ZipFile('/tmp/tf.zip').extractall(os.path.expanduser('~/bin'))"
  chmod +x ~/bin/terraform
  hash -r
fi
have_tf || { echo "Terraform still not available, stopping."; exit 1; }
terraform version
 
# ---- read the pre-existing instances so the config matches them ----
INFO=$(gcloud compute instances list --filter="name~^tf-instance-[12]\$" \
  --format="value(name,zone.basename(),machineType.basename(),networkInterfaces[0].network.basename())" 2>/dev/null)
echo "Existing instances:"; echo "$INFO"
MT1=$(echo "$INFO" | awk '$1=="tf-instance-1"{print $3}'); MT1=${MT1:-e2-micro}
MT2=$(echo "$INFO" | awk '$1=="tf-instance-2"{print $3}'); MT2=${MT2:-e2-micro}
NET1=$(echo "$INFO" | awk '$1=="tf-instance-1"{print $4}'); NET1=${NET1:-default}
NET2=$(echo "$INFO" | awk '$1=="tf-instance-2"{print $4}'); NET2=${NET2:-default}
REALZ=$(echo "$INFO" | awk 'NR==1{print $2}')
if [ -n "$REALZ" ] && [ "$REALZ" != "$ZONE" ]; then
  echo "NOTE: existing instances are in $REALZ, not $ZONE - adapting zone/region to match."
  ZONE=$REALZ; REGION=${REALZ%-*}
fi
echo "Using region=$REGION zone=$ZONE bucket=$BUCKET third=$THIRD vpc=$VPC"
 
# ---------------- file writers ----------------
write_vars(){  # $1 = target file
cat > "$1" <<EOF
variable "region" {
  default = "$REGION"
}
 
variable "zone" {
  default = "$ZONE"
}
 
variable "project_id" {
  default = "$PROJECT"
}
EOF
}
 
S_STORAGE=0; S_BACKEND=0; S_VPC=0; S_FW=0
write_main(){
cat > main.tf <<EOF
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
EOF
[ "$S_BACKEND" = 1 ] && cat >> main.tf <<EOF
  backend "gcs" {
    bucket = "$BUCKET"
    prefix = "terraform/state"
  }
EOF
cat >> main.tf <<EOF
}
 
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
 
module "instances" {
  source     = "./modules/instances"
  project_id = var.project_id
  region     = var.region
  zone       = var.zone
}
EOF
[ "$S_STORAGE" = 1 ] && cat >> main.tf <<EOF
 
module "storage" {
  source     = "./modules/storage"
  project_id = var.project_id
  region     = var.region
  zone       = var.zone
}
EOF
[ "$S_VPC" = 1 ] && cat >> main.tf <<EOF
 
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "10.0.0"
 
  project_id   = var.project_id
  network_name = "$VPC"
  routing_mode = "GLOBAL"
 
  subnets = [
    {
      subnet_name   = "subnet-01"
      subnet_ip     = "10.10.10.0/24"
      subnet_region = "$REGION"
    },
    {
      subnet_name   = "subnet-02"
      subnet_ip     = "10.10.20.0/24"
      subnet_region = "$REGION"
    },
  ]
}
EOF
[ "$S_FW" = 1 ] && cat >> main.tf <<EOF
 
resource "google_compute_firewall" "tf-firewall" {
  name          = "tf-firewall"
  network       = "projects/$PROJECT/global/networks/$VPC"
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
 
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}
EOF
}
 
inst(){  # label name machine network subnetwork-line
cat <<EOF
resource "google_compute_instance" "$1" {
  name         = "$2"
  machine_type = "$3"
  zone         = var.zone
 
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
 
  network_interface {
    network = "$4"
$5
  }
 
  metadata_startup_script = <<-EOT
        #!/bin/bash
    EOT
  allow_stopping_for_update = true
}
 
EOF
}
 
# write_instances MT1 MT2 WITH_THIRD USE_VPC
write_instances(){
  local n1=$NET1 n2=$NET2 s1="" s2="" t3=""
  if [ "$4" = 1 ]; then n1=$VPC; n2=$VPC; s1='    subnetwork = "subnet-01"'; s2='    subnetwork = "subnet-02"'; fi
  {
    inst tf-instance-1 tf-instance-1 "$1" "$n1" "$s1"
    inst tf-instance-2 tf-instance-2 "$2" "$n2" "$s2"
    [ "$3" = 1 ] && inst tf-instance-3 "$THIRD" "e2-standard-2" "$n1" "$s1"
  } > modules/instances/instances.tf
}
 
tfinit(){ must terraform init -input=false; }
tfapply(){ must terraform apply -input=false -auto-approve; }
 
# ================= Task 1 =================
say "Task 1: create configuration files"
mkdir -p "$WORK/modules/instances" "$WORK/modules/storage"
cd "$WORK"
write_vars variables.tf
write_vars modules/instances/variables.tf
write_vars modules/storage/variables.tf
cat > modules/instances/outputs.tf <<'EOF'
output "instance_1_id" {
  value = google_compute_instance.tf-instance-1.instance_id
}
 
output "instance_2_id" {
  value = google_compute_instance.tf-instance-2.instance_id
}
EOF
: > modules/storage/storage.tf
: > modules/storage/outputs.tf
write_main
write_instances "$MT1" "$MT2" 0 0
tfinit
 
# ================= Task 2 =================
say "Task 2: import existing instances"
imp(){
  terraform state list 2>/dev/null | grep -q "^module.instances.google_compute_instance.$1\$" || \
  must terraform import "module.instances.google_compute_instance.$1" "projects/$PROJECT/zones/$ZONE/instances/$1"
}
imp tf-instance-1
imp tf-instance-2
tfapply
pause "Task 2 - Import infrastructure"
 
# ================= Task 3 =================
say "Task 3: storage bucket + remote backend"
cat > modules/storage/storage.tf <<EOF
resource "google_storage_bucket" "tf-bucket" {
  name                        = "$BUCKET"
  project                     = var.project_id
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = true
}
EOF
cat > modules/storage/outputs.tf <<'EOF'
output "bucket_name" {
  value = google_storage_bucket.tf-bucket.name
}
EOF
S_STORAGE=1; write_main
tfinit
tfapply
S_BACKEND=1; write_main
must terraform init -migrate-state -force-copy -input=false
tfapply
pause "Task 3 - Configure a remote backend"
 
# ================= Task 4 =================
say "Task 4: e2-standard-2 on all instances + third instance"
write_instances e2-standard-2 e2-standard-2 1 0
tfinit
tfapply
pause "Task 4 - Modify and update infrastructure"
 
# ================= Task 5 =================
say "Task 5: destroy the third instance"
write_instances e2-standard-2 e2-standard-2 0 0
tfinit
tfapply
pause "Task 5 - Destroy resources"
 
# ================= Task 6 =================
say "Task 6: registry VPC module, then attach instances to subnets"
S_VPC=1; write_main
tfinit
tfapply
write_instances e2-standard-2 e2-standard-2 0 1
tfinit
tfapply
pause "Task 6 - Use a module from the Registry"
 
# ================= Task 7 =================
say "Task 7: firewall"
S_FW=1; write_main
tfinit
tfapply
pause "Task 7 - Configure a firewall"
 
say "ALL DONE"
gcloud compute instances list --filter="name~^tf-instance" --format="table(name,zone.basename(),machineType.basename(),status)"
