# sre-labs

Hands-on site reliability engineering labs, one a week from October 2026 to March 2027.

Everything starts on my own Ubuntu Server VM in VirtualBox, then moves to Docker, AWS and Kubernetes. Each lab folder has my notes and any scripts or config files I wrote for it.

## Labs

| # | Lab | Status |
|---|---|---|
| 01 | [Your own Linux server](lab01-linux-server/notes.md) | Done |
| 02 | Permissions and processes | |
| 03 | Bash scripting | |
| 04 | systemd services and a full disk | |
| 05 | Networking: OSI and subnetting | |
| 06 | Two VMs talking | |
| 07 | DNS, HTTP and a TCP handshake | |
| 08 | Hypervisors | |
| 09 | Nutanix: AOS and HCI | |
| 10 | Nutanix: AHV and Prism | |
| 11 | Containers are just Linux | |
| 12 | Prometheus and Grafana | |
| 13 | Instrumenting an app | |
| 14 | Dashboards and SLO alerts | |
| 15 | Linux troubleshooting drills | |
| 16 | Troubleshooting out loud | |
| 17 | SadServers, medium | |
| 18 | Breaking Kubernetes | |
| 19 | Troubleshooting mock #1 | |
| 20 | Internship write-up | |
| 21 | Terraform basics | |
| 22 | Capacity planning | |
| 23 | Troubleshooting mock #2 | |
| 24 | Kubernetes from memory | |
| 25 | SadServers, hard | |
| 26 | Debrief | |

## Setup

- Host: MacBook (Apple M3)
- Hypervisor: VirtualBox
- Guest: Ubuntu Server 26.04.1 LTS, ARM64, 2 CPUs, 2 GB RAM, 25 GB disk
- Access: ssh over a NAT port forward, Mac port 2222 to VM port 22