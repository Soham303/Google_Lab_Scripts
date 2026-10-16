#!/bin/bash
# Internal Network Load Balancer lab - one idempotent run, no SSH needed.
# Run inside tmux:  tmux new -s lab   then   bash ilb_lab_v1.sh 2>&1 | tee ilb.log
# Override regions if your lab differs, e.g.:  REGION=us-east4 bash ilb_lab_v1.sh
PROJECT=$(gcloud config get-value project 2>/dev/null)
REGION=${REGION:-us-east4}
ZONE_UTIL=${ZONE_UTIL:-us-east4-a}
ZONE_IG1=${ZONE_IG1:-us-east4-b}
ZONE_IG2=${ZONE_IG2:-us-east4-c}
NET=my-internal-app
ILB_IP=10.10.30.5
UTIL_IP=10.10.20.50
 
say(){ echo; echo "=== $(date +%T) $* ==="; }
has(){ "$@" >/dev/null 2>&1; }
retry(){ for i in 1 2 3; do "$@" && return 0; echo "  (attempt $i failed, retrying in 10s)"; sleep 10; done; echo "FAILED: $*"; return 1; }
must(){ retry "$@" || { echo "STOPPING: step failed, see error above."; exit 1; }; }
 
gcloud config set compute/region $REGION >/dev/null 2>&1
gcloud services enable compute.googleapis.com >/dev/null 2>&1
 
say "Task 1: firewall rules"
has gcloud compute firewall-rules describe fw-allow-lb-access || \
must gcloud compute firewall-rules create fw-allow-lb-access --network=$NET \
  --direction=INGRESS --action=allow --target-tags=backend-service \
  --source-ranges=10.10.0.0/16 --rules=all --quiet
has gcloud compute firewall-rules describe fw-allow-health-checks || \
must gcloud compute firewall-rules create fw-allow-health-checks --network=$NET \
  --direction=INGRESS --action=allow --target-tags=backend-service \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 --rules=tcp:80 --quiet
 
say "Task 2: Cloud Router + NAT"
has gcloud compute routers describe nat-router-us-east4 --region=$REGION || \
must gcloud compute routers create nat-router-us-east4 --network=$NET --region=$REGION --quiet
has gcloud compute routers nats describe nat-config --router=nat-router-us-east4 --region=$REGION || \
must gcloud compute routers nats create nat-config --router=nat-router-us-east4 --region=$REGION \
  --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges --quiet
echo "Giving NAT 60s to become active..."; sleep 60
 
say "Task 3: re-run backend startup scripts (VM reset, no SSH) + utility-vm"
if ! has gcloud compute instances describe utility-vm --zone=$ZONE_UTIL; then
  gcloud compute instances list --filter="name~^instance-group-" \
    --format="value(name,zone.basename())" | while read N Z; do
      [ -n "$N" ] && { echo "Resetting $N ($Z) so its startup script runs with NAT available"; \
        gcloud compute instances reset $N --zone=$Z --quiet; }
    done
fi
 
# real backend IPs (lab says 10.10.20.2 and 10.10.30.2, but read them to be safe)
BACKENDS=$(gcloud compute instances list --filter="name~^instance-group-" \
  --format="value(networkInterfaces[0].networkIP)" | tr '\n' ' ')
echo "Backend IPs: $BACKENDS"
[ -z "$BACKENDS" ] && BACKENDS="10.10.20.2 10.10.30.2"
 
cat > /tmp/util-startup.sh <<EOF
#!/bin/bash
echo "UTIL: waiting for backends"
for ip in $BACKENDS; do
  for i in \$(seq 1 90); do
    curl -s -m3 http://\$ip | grep -q "Internal Load Balancing Lab" && { echo "UTIL_BACKEND_OK \$ip"; break; }
    sleep 10
  done
done
echo "UTIL: waiting for ILB $ILB_IP"
for i in \$(seq 1 90); do
  curl -s -m3 http://$ILB_IP | grep -q "Internal Load Balancing Lab" && { echo "UTIL_ILB_OK"; break; }
  sleep 10
done
for i in \$(seq 1 10); do
  echo "ILB_RESPONSE: \$(curl -s -m3 http://$ILB_IP | sed 's/<[^>]*>/ /g')"
done
echo "UTIL_DONE"
EOF
 
has gcloud compute instances describe utility-vm --zone=$ZONE_UTIL || \
must gcloud compute instances create utility-vm --zone=$ZONE_UTIL --machine-type=e2-medium \
  --image-family=debian-12 --image-project=debian-cloud \
  --network=$NET --subnet=subnet-a --private-network-ip=$UTIL_IP --no-address \
  --metadata-from-file=startup-script=/tmp/util-startup.sh --quiet
 
say "Task 4: internal Network Load Balancer"
has gcloud compute health-checks describe my-ilb-health-check --region=$REGION || \
must gcloud compute health-checks create tcp my-ilb-health-check --region=$REGION --port=80 \
  --check-interval=10s --timeout=5s --healthy-threshold=2 --unhealthy-threshold=3 --quiet
 
has gcloud compute backend-services describe my-ilb --region=$REGION || \
must gcloud compute backend-services create my-ilb --region=$REGION \
  --load-balancing-scheme=INTERNAL --protocol=TCP --network=$NET \
  --health-checks=my-ilb-health-check --health-checks-region=$REGION --quiet
 
BE=$(gcloud compute backend-services describe my-ilb --region=$REGION --format="value(backends[].group)")
echo "$BE" | grep -q "instance-group-1" || \
must gcloud compute backend-services add-backend my-ilb --region=$REGION \
  --instance-group=instance-group-1 --instance-group-zone=$ZONE_IG1 --quiet
echo "$BE" | grep -q "instance-group-2" || \
must gcloud compute backend-services add-backend my-ilb --region=$REGION \
  --instance-group=instance-group-2 --instance-group-zone=$ZONE_IG2 --quiet
 
has gcloud compute addresses describe my-ilb-ip --region=$REGION || \
must gcloud compute addresses create my-ilb-ip --region=$REGION --subnet=subnet-b \
  --addresses=$ILB_IP --quiet
 
has gcloud compute forwarding-rules describe my-ilb-forwarding-rule --region=$REGION || \
must gcloud compute forwarding-rules create my-ilb-forwarding-rule --region=$REGION \
  --load-balancing-scheme=INTERNAL --network=$NET --subnet=subnet-b \
  --address=my-ilb-ip --ip-protocol=TCP --ports=80 \
  --backend-service=my-ilb --backend-service-region=$REGION --quiet
 
say "Task 5: waiting for utility-vm to test the ILB (prints every 30s, max ~25 min)"
for i in $(seq 1 50); do
  OUT=$(gcloud compute instances get-serial-port-output utility-vm --zone=$ZONE_UTIL 2>/dev/null)
  echo "$OUT" | grep -q "UTIL_DONE" && { echo "Test finished."; break; }
  echo "  still waiting ($i/50): $(echo "$OUT" | grep -o 'UTIL_[A-Z_]*' | tail -1)"
  sleep 30
done
echo
echo "---- ILB test results (from utility-vm) ----"
echo "$OUT" | grep -E "UTIL_BACKEND_OK|UTIL_ILB_OK|ILB_RESPONSE" | sed 's/^.*startup-script: //'
 
say "ALL DONE. Click 'Check my progress' on Tasks 1, 2, 3 and 4, then End Lab."
