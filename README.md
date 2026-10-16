# Google Cloud Lab Automation Scripts

This repository contains automation scripts and execution instructions for Google Cloud Skills Boost / Google Cloud Labs. Each folder corresponds to a lab, containing the shell script and step-by-step terminal instructions.

## Directory Structure

Each lab is structured as follows:
```text
Lab Name/
├── <script_name>.sh
└── instructions.txt
```

## Available Labs

| # | Lab Title | Script | Instructions |
|---|---|---|---|
| 1 | [Configure an Application Load Balancer with Autoscaling](./Configure%20an%20Application%20Load%20Balancer%20with%20Autoscaling) | `ocbl105_v2.sh` | [instructions.txt](./Configure%20an%20Application%20Load%20Balancer%20with%20Autoscaling/instructions.txt) |
| 2 | [A Tour of Google Cloud Hands-on Labs](./A%20Tour%20of%20Google%20Cloud%20Hands-on%20Labs) | `gsp282.sh` | [instructions.txt](./A%20Tour%20of%20Google%20Cloud%20Hands-on%20Labs/instructions.txt) |
| 3 | [Creating a Virtual Machine](./Creating%20a%20Virtual%20Machine) | `gsp001.sh` | [instructions.txt](./Creating%20a%20Virtual%20Machine/instructions.txt) |
| 4 | [Getting Started with Cloud Shell and gcloud](./Getting%20Started%20with%20Cloud%20Shell%20and%20gcloud) | `gsp002.sh` | [instructions.txt](./Getting%20Started%20with%20Cloud%20Shell%20and%20gcloud/instructions.txt) |
| 5 | [Cloud IAM: Qwik Start](./Cloud%20IAM%20Qwik%20Start) | `gsp064.sh` | [instructions.txt](./Cloud%20IAM%20Qwik%20Start/instructions.txt) |
| 6 | [Cloud Storage: Qwik Start - CLI/SDK](./Cloud%20Storage%20Qwik%20Start%20-%20CLI%20SDK) | `gsp074.sh` | [instructions.txt](./Cloud%20Storage%20Qwik%20Start%20-%20CLI%20SDK/instructions.txt) |
| 7 | [Multiple VPC Networks](./Multiple%20VPC%20Networks) | `gsp211.sh` | [instructions.txt](./Multiple%20VPC%20Networks/instructions.txt) |
| 8 | [Implement Private Google Access and Cloud NAT](./Implement%20Private%20Google%20Access%20and%20Cloud%20NAT) | `gsp214.sh` | [instructions.txt](./Implement%20Private%20Google%20Access%20and%20Cloud%20NAT/instructions.txt) |

## General Usage Guide

1. Open **Google Cloud Shell** from your active lab session.
2. Clone or download the desired lab script.
3. Use `tmux` to ensure long-running jobs are not interrupted by transient connection drops:
   ```bash
   tmux new -s lab
   ```
4. Run the script according to the parameters specified in its `instructions.txt`.
5. If disconnected, resume with:
   ```bash
   tmux attach -t lab
   ```
6. Once the script outputs `ALL DONE`, click **Check my progress** for all tasks and complete the lab.
