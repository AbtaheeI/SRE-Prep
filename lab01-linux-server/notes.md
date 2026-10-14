# Lab 1: Your own Linux server

Ubuntu Server 26.04.1 LTS (ARM64) running in VirtualBox on an M3 Mac. No desktop, logged into over ssh from the Mac terminal.

## Setup

- VM name: `sre-lab`
- 2 CPUs, 2048 MB RAM, 25 GB disk (dynamically allocated, EFI on)
- Ubuntu Server (not minimized), OpenSSH left unticked in the installer and installed manually after
- Network: NAT with a port forward, host `2222` to guest `22`
- Snapshot: `lab1-clean`

## Commands

```bash
sudo apt update                    # refresh the package list
sudo apt install openssh-server    # install the ssh server
systemctl status ssh               # is the ssh service running? (q to exit)
systemctl status ssh.socket        # is the socket listening on port 22?
sudo poweroff                      # shut the VM down cleanly
```

From the Mac:

```bash
ssh -p 2222 malzi@127.0.0.1
```

## Concepts

**Host vs guest**
- Host: the physical computer the VM runs on (the Mac). It gives out the CPU, memory and disk.
- Guest: the virtual machine. Everything it uses is borrowed from the host. The VM's disk is just a file on the Mac (`sre-lab.vdi`).

**Hypervisor**
- Software that creates VMs and shares the host's hardware between them.
- Type 2: runs as an app on top of a normal OS. VirtualBox on macOS.
- Type 1: runs directly on the hardware, no OS underneath. Nutanix AHV, VMware ESXi.

**sudo**
- Runs a command as the admin user, called root.

**Active vs enabled (systemd)**
- Active: running right now.
- Enabled: starts automatically when the machine boots.
- `ssh.service` showed inactive (dead) at first because of socket activation. `ssh.socket` listens on port 22 and only starts `ssh.service` when someone connects. Saves memory when nobody is using ssh. After logging in, `ssh.service` showed active (running).

**127.0.0.1**
- Always means "this computer". Also called localhost.

**The port forward path**
- My terminal connects to my Mac on port 2222, VirtualBox forwards it to the VM on port 22, and ssh.socket on the VM picks it up.
- In the VM's ssh log the connection shows as coming from `10.0.2.2`. That's how the VM sees the Mac through VirtualBox's NAT.

**VM IP address**
- The VM's IP is `10.0.2.15`, inside VirtualBox's hidden NAT network. The Mac can't reach it directly, which is why the port forward is needed.

**Host key fingerprint**
- The first ssh login asked "are you sure?" and showed a fingerprint. It matched the one printed on the VM's boot screen. That check proves you're talking to the real server and not an imposter.

## Things to come back to

- Disk shows `10.70GB` for `/` even though the VM has 25 GB. The installer only used part of the disk. Week 4.

## Starting the VM next time

VirtualBox, select `sre-lab`, Start, Headless Start. Then ssh in from the Mac terminal.