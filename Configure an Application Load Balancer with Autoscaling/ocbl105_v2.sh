#!/bin/bash
# OCBL105 FINAL: idempotent (safe to re-run), retries transient errors, no SSH needed.
# Run inside tmux:  tmux new -s lab   then   bash lab_final.sh 2>&1 | tee lab.log
PROJECT=$(gcloud config get-value project 2>/dev/null)
echo "Current Project: $PROJECT"

# Dynamic Region and Zone inputs (uses env vars if passed, prompts interactively with defaults otherwise)
if [ -z "$R1" ]; then
  read -p "Enter Region 1 (default: us-east1): " input_r1
  R1=${input_r1:-us-east1}
fi
if [ -z "$Z1" ]; then
  read -p "Enter Zone 1 (default: ${R1}-d): " input_z1
  Z1=${input_z1:-${R1}-d}
fi
if [ -z "$R2" ]; then
  read -p "Enter Region 2 (default: asia-southeast1): " input_r2
  R2=${input_r2:-asia-southeast1}
fi
if [ -z "$ZS" ]; then
  read -p "Enter Stress Test Zone (default: us-east4-a): " input_zs
  ZS=${input_zs:-us-east4-a}
fi
echo "Using parameters: R1=$R1 Z1=$Z1 R2=$R2 ZS=$ZS"

say(){ echo; echo "=== $(date +%T) $* ==="; }
has(){ "$@" >/dev/null 2>&1; }
retry(){ for i in 1 2 3; do "$@" && return 0; echo "  (attempt $i failed, retrying in 10s)"; sleep 10; done; echo "FAILED: $*"; return 1; }
must(){ retry "$@" || { echo "STOPPING: step failed, see error above."; exit 1; }; }
 
gcloud config set compute/region $R1 >/dev/null 2>&1
gcloud services enable compute.googleapis.com >/dev/null 2>&1
 
say "Task 1: firewall rule"
has gcloud compute firewall-rules describe fw-allow-health-checks || \
must gcloud compute firewall-rules create fw-allow-health-checks --network=default \
  --direction=INGRESS --action=allow --target-tags=allow-health-checks \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 --rules=tcp:80 --quiet
 
say "Task 2: Cloud Router + NAT"
has gcloud compute routers describe nat-router-us1 --region=$R1 || \
must gcloud compute routers create nat-router-us1 --network=default --region=$R1 --quiet
has gcloud compute routers nats describe nat-config --router=nat-router-us1 --region=$R1 || \
must gcloud compute routers nats create nat-config --router=nat-router-us1 --region=$R1 \
  --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges --quiet
 
say "Task 3: custom image"
if ! has gcloud compute images describe mywebserver; then
  if ! has gcloud compute disks describe webserver --zone=$Z1; then
    cat > /tmp/web-startup.sh <<'EOF'
#!/bin/bash
for i in 1 2 3 4 5 6; do apt-get update && apt-get install -y apache2 && break; sleep 10; done
systemctl enable apache2
systemctl start apache2
EOF
    must gcloud compute instances create webserver --zone=$Z1 --machine-type=e2-small \
      --network=default --no-address --tags=allow-health-checks --no-boot-disk-auto-delete \
      --metadata-from-file=startup-script=/tmp/web-startup.sh --quiet
    echo "Waiting for Apache install (serial log, no SSH)..."
    for i in $(seq 1 60); do
      gcloud compute instances get-serial-port-output webserver --zone=$Z1 2>/dev/null \
        | grep -q "Finished running startup scripts" && break
      sleep 10
    done
    gcloud compute instances stop webserver --zone=$Z1 --quiet
    must gcloud compute instances delete webserver --zone=$Z1 --keep-disks=boot --quiet
  fi
  must gcloud compute images create mywebserver --source-disk=webserver --source-disk-zone=$Z1 --quiet
fi
 
say "Task 4: template, health check, MIGs"
has gcloud compute instance-templates describe mywebserver-template || \
must gcloud compute instance-templates create mywebserver-template --machine-type=e2-micro \
  --image=mywebserver --image-project=$PROJECT --network=default --no-address \
  --tags=allow-health-checks --quiet
has gcloud compute health-checks describe http-health-check || \
must gcloud compute health-checks create http http-health-check --port=80 --quiet
for spec in "us-1-mig:$R1" "notus-1-mig:$R2"; do
  N=${spec%%:*}; R=${spec##*:}
  has gcloud compute instance-groups managed describe $N --region=$R || \
  must gcloud compute instance-groups managed create $N --region=$R --template=mywebserver-template \
    --size=1 --health-check=http-health-check --initial-delay=60 --quiet
  must gcloud compute instance-groups set-named-ports $N --region=$R --named-ports=http:80 --quiet
done
 
say "Task 5: backend service"
has gcloud compute backend-services describe http-backend --global || \
must gcloud compute backend-services create http-backend --global --protocol=HTTP --port-name=http \
  --load-balancing-scheme=EXTERNAL_MANAGED --health-checks=http-health-check \
  --enable-logging --logging-sample-rate=1.0 --quiet
BE=$(gcloud compute backend-services describe http-backend --global --format="value(backends[].group)")
echo "$BE" | grep -q "/us-1-mig" || \
must gcloud compute backend-services add-backend http-backend --global \
  --instance-group=us-1-mig --instance-group-region=$R1 \
  --balancing-mode=RATE --max-rate-per-instance=50 --capacity-scaler=1.0 --quiet
echo "$BE" | grep -q "/notus-1-mig" || \
must gcloud compute backend-services add-backend http-backend --global \
  --instance-group=notus-1-mig --instance-group-region=$R2 \
  --balancing-mode=UTILIZATION --max-utilization=0.8 --capacity-scaler=1.0 --quiet
for spec in "us-1-mig:$R1" "notus-1-mig:$R2"; do
  N=${spec%%:*}; R=${spec##*:}
  must gcloud compute instance-groups managed set-autoscaling $N --region=$R \
    --min-num-replicas=1 --max-num-replicas=2 \
    --target-load-balancing-utilization=0.8 --cool-down-period=60 --quiet
done
 
has gcloud compute url-maps describe http-lb --global || \
must gcloud compute url-maps create http-lb --default-service=http-backend --global --quiet
has gcloud compute target-http-proxies describe http-lb-target-proxy --global || \
must gcloud compute target-http-proxies create http-lb-target-proxy --url-map=http-lb --global --quiet
has gcloud compute forwarding-rules describe http-lb-forwarding-rule --global || \
must gcloud compute forwarding-rules create http-lb-forwarding-rule --global \
  --load-balancing-scheme=EXTERNAL_MANAGED --target-http-proxy=http-lb-target-proxy \
  --ports=80 --ip-version=IPV4 --network-tier=PREMIUM --quiet
has gcloud compute forwarding-rules describe http-lb-forwarding-rule-ipv6 --global || \
must gcloud compute forwarding-rules create http-lb-forwarding-rule-ipv6 --global \
  --load-balancing-scheme=EXTERNAL_MANAGED --target-http-proxy=http-lb-target-proxy \
  --ports=80 --ip-version=IPV6 --network-tier=PREMIUM --quiet
 
LB_IP=$(gcloud compute forwarding-rules describe http-lb-forwarding-rule --global --format='value(IPAddress)')
echo "LB IPv4: $LB_IP"
[ -z "$LB_IP" ] && { echo "No LB IP, stopping."; exit 1; }
 
say "Waiting for LB to serve (max ~15 min; prints every 30s)"
for i in $(seq 1 30); do
  curl -m 5 -s http://$LB_IP/ | grep -q Apache && { echo "LB is up"; break; }
  echo "  still waiting ($i/30)..."; sleep 30
done
 
say "Task 6: stress test"
cat > /tmp/stress-startup.sh <<EOF
#!/bin/bash
ulimit -n 65535
cd /tmp
nohup ab -t 360 -n 5000000 -c 300 http://$LB_IP/ > /tmp/ab.log 2>&1 &
EOF
if [ -z "$(gcloud compute instances list --filter='name=stress-test' --format='value(name)')" ]; then
  CREATED=0
  for z in $ZS us-east1-b us-central1-a us-east4-a us-east4-c; do
    echo "Trying stress-test in $z..."
    if gcloud compute instances create stress-test --zone=$z --machine-type=e2-micro \
        --image=mywebserver --image-project=$PROJECT \
        --metadata-from-file=startup-script=/tmp/stress-startup.sh --quiet; then
      CREATED=1; break
    fi
  done
  [ $CREATED -eq 1 ] || { echo "Could not create stress-test in any zone."; exit 1; }
fi
 
say "Load running ~6 min (prints every 30s so the session stays active)"
for i in $(seq 1 14); do echo "  load test... $((i*30))s"; sleep 30; done
 
say "ALL DONE. Click 'Check my progress' on each task, then End Lab."
gcloud compute instance-groups managed list --format="table(name,region,targetSize)"
