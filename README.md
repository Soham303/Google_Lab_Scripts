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
