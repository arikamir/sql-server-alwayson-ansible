# SQL Server Always-On Availability Group Ansible Automation

Automated deployment of a **two-node SQL Server Always-On Availability Group** on Windows using Ansible from a Linux/macOS control node.

## Overview

This project provides complete Ansible automation for setting up SQL Server Always-On Availability Groups on Windows Server 2022 with SQL Server 2022 Enterprise Edition. The solution uses community roles and modules to configure Windows Server Failover Clustering (WSFC), enable Always-On features, create availability groups, and configure listeners.

## Features

- ✅ Automated Windows Server Failover Cluster configuration
- ✅ Always-On Availability Groups feature enablement
- ✅ Availability group creation with automatic seeding
- ✅ Listener configuration with static IP addresses
- ✅ Cluster and AG health validation
- ✅ Idempotent playbooks for safe re-runs
- ✅ Support for synchronous/asynchronous replication
- ✅ Automatic and manual failover modes

## Prerequisites

### Windows Environment
- **Windows Server 2022** (or later) with Failover Clustering feature installed
- **SQL Server 2022 Enterprise Edition** installed as default instance
- Both nodes joined to the same Active Directory domain
- Domain service account for SQL Server service with appropriate SPNs
- Static IPs or DHCP reservations for nodes, cluster, and listener
- Required firewall ports open:
  - UDP/TCP 3343 (clustering)
  - TCP 1433 (SQL Server)
  - TCP 5022 (AG endpoints)
  - TCP 5986 (WinRM)

### Linux/macOS Control Node
- **Ansible 8+** with Python 3.9+
- WinRM configured to reach Windows hosts
- Required Ansible collections (see Installation)

### Service Accounts
- Domain account for SQL Server service
- Domain administrator credentials for cluster operations
- File-share witness on separate server for quorum

## Installation

### 1. Run the Setup Script

```bash
chmod +x setup_prereqs.sh
./setup_prereqs.sh
```

This script will:
- Create a Python virtual environment
- Install Ansible 8+ and WinRM dependencies
- Install required Ansible Galaxy collections

### 2. Manual Collection Installation (Alternative)

```bash
ansible-galaxy collection install ansible.windows:2.8.0
ansible-galaxy collection install community.windows:2.4.0
ansible-galaxy collection install oatakan.windows_cluster:1.0.3
ansible-galaxy collection install oatakan.windows_sql_server:1.0.5
ansible-galaxy collection install lowlydba.sqlserver:2.6.1
```

## Configuration

### 1. Update Inventory

Edit `inventory/hosts.yml` to define your Windows nodes:

```yaml
all:
  vars:
    ansible_connection: winrm
    ansible_port: 5986
    ansible_winrm_scheme: https
    ansible_user: "{{ winrm_username }}"
    ansible_password: "{{ winrm_password }}"
  children:
    sql_primary:
      hosts:
        sql01:
          ansible_host: 192.168.10.101
    sql_secondary:
      hosts:
        sql02:
          ansible_host: 192.168.10.102
```

### 2. Configure Variables

Edit `group_vars/all.yml` to set your environment-specific values:

```yaml
cluster_name: SqlCluster01
ag_name: SalesAg
ag_databases:
  - SalesDb
listener_name: SqlAgListener01
listener_ips:
  - address: 192.168.10.125
    subnet_mask: 255.255.255.0
sql_svc_account: EXAMPLE\\sqlsvc
ag_failover_mode: Automatic
ag_synchronization_mode: SynchronousCommit
```

### 3. Secure Credentials

Use Ansible Vault for sensitive data:

```bash
ansible-vault create group_vars/vault.yml
```

Add encrypted variables:
```yaml
vault_sql_svc_password: YourSecurePassword
vault_domain_admin_password: YourAdminPassword
winrm_username: Administrator
winrm_password: YourWinRMPassword
```

## Usage

### Run the Complete Setup

```bash
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass
```

### Run Specific Roles

```bash
# Only configure the cluster
ansible-playbook -i inventory/hosts.yml site.yml --tags cluster

# Only enable Always-On
ansible-playbook -i inventory/hosts.yml site.yml --tags alwayson

# Only create availability group
ansible-playbook -i inventory/hosts.yml site.yml --tags availability_group

# Only configure listener
ansible-playbook -i inventory/hosts.yml site.yml --tags listener

# Only run validation
ansible-playbook -i inventory/hosts.yml site.yml --tags validation
```

## Project Structure

```
.
├── README.md                          # This file
├── site.yml                           # Main playbook
├── setup_prereqs.sh                   # Setup script
├── inventory/
│   └── hosts.yml                      # Inventory definition
├── group_vars/
│   └── all.yml                        # Group variables
└── roles/
    ├── windows_cluster/               # WSFC configuration
    │   └── tasks/main.yml
    ├── enable_alwayson/               # Enable Always-On feature
    │   └── tasks/main.yml
    ├── availability_group/            # Create AG and replicas
    │   └── tasks/main.yml
    ├── ag_listener/                   # Configure listener
    │   └── tasks/main.yml
    └── validate_cluster/              # Validation tasks
        └── tasks/main.yml
```

## Roles

### windows_cluster
Configures Windows Server Failover Cluster:
- Installs clustering features
- Creates cluster on primary node
- Joins secondary node
- Configures file-share witness quorum

### enable_alwayson
Enables Always-On Availability Groups:
- Configures SQL Server service account
- Enables Always-On feature via registry
- Restarts SQL Server service

### availability_group
Creates the availability group:
- Creates database mirroring endpoints
- Configures replicas with seeding mode
- Creates availability group on primary
- Joins secondary replica
- Adds databases to AG

### ag_listener
Configures the availability group listener:
- Creates listener with specified name and port
- Assigns static IP addresses

### validate_cluster
Validates the deployment:
- Checks WSFC group status
- Verifies AG health using dbatools
- Optional manual failover test

## Configuration Options

### Synchronization Modes
- `SynchronousCommit` - Data committed on both replicas (recommended for automatic failover)
- `AsynchronousCommit` - Data committed on primary only (better performance, data loss possible)

### Failover Modes
- `Automatic` - Automatic failover on primary failure (requires SynchronousCommit)
- `Manual` - Manual failover only

### Seeding Modes
- `Automatic` - SQL Server automatically seeds secondary databases
- `Manual` - Use backup/restore to seed secondary

## Troubleshooting

### WinRM Connection Issues
```bash
# Test WinRM connectivity
ansible all -i inventory/hosts.yml -m win_ping
```

### Check Cluster Status
```powershell
Get-Cluster -Name SqlCluster01
Get-ClusterNode
```

### Check Availability Group Status
```powershell
Import-Module dbatools
Get-DbaAvailabilityGroup -SqlInstance localhost
```

### Enable Verbose Output
```bash
ansible-playbook -i inventory/hosts.yml site.yml -vvv
```

## Documentation

For detailed information, see:
- [allways-on-ansiblesetup.md](allways-on-ansiblesetup.md) - Comprehensive setup guide
- [prompt.md](prompt.md) - Original requirements and specifications

## Requirements

- Ansible >= 8.0.0
- Python >= 3.9
- pywinrm
- pywinrm[credssp]
- pypsrp

## Collections Used

- `ansible.windows` (2.8.0)
- `community.windows` (2.4.0)
- `oatakan.windows_cluster` (1.0.3)
- `oatakan.windows_sql_server` (1.0.5)
- `lowlydba.sqlserver` (2.6.1)

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues and questions:
- Check the [troubleshooting section](#troubleshooting)
- Review the detailed setup guide in `allways-on-ansiblesetup.md`
- Open an issue on GitHub

## Author

Created for automated SQL Server Always-On deployments using Ansible best practices.
