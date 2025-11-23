# SQL Server Always‑On High Availability Setup Using Ansible (Two‑Node Cluster)

## Overview

This guide shows how to automate the deployment of a **two‑node SQL Server Always‑On Availability Group** on Windows using **Ansible** from a Linux control node.  The procedure assumes that each Windows Server VM is prepared from a template containing:

- **Windows Server 2022** (or later) with the **Failover Clustering** feature installed but **not configured**.
- **SQL Server 2022** Enterprise Edition installed as the default instance.  The installation must not be configured for high availability yet.
- A Linux or macOS control node running **Ansible** with WinRM configured to reach the Windows hosts.

The solution uses community Ansible roles and modules from the *oatakan.windows_cluster*, *oatakan.windows_sql_server* and *lowlydba.sqlserver* collections.  These roles wrap the underlying Windows PowerShell and `dbatools` commands needed to build the cluster, enable Always‑On and create the availability group and listener.  You can extend or customise the roles to meet your environment’s requirements.

## 1 Prerequisites

### 1.1 Windows and SQL Server requirements

- **Cluster membership** – Each SQL instance that hosts an availability replica must run on a node of a **Windows Server Failover Cluster (WSFC)**【723384504335133†L696-L704】.
- **Same version and collation** – All replicas must run the **same SQL Server version** and **same server collation**【723384504335133†L739-L746】.
- **Service account and SPNs** – If Kerberos is needed, all replicas must run under the **same SQL Server service account**, and a domain administrator must register an **SPN** on that account for the **virtual network name (VNN)** of the availability group listener【723384504335133†L710-L717】.  If the SQL service account is changed, the SPN must be re‑registered【723384504335133†L723-L724】.
- **Enable Always‑On** – Each SQL Server instance must have the **Always‑On Availability Groups** feature enabled【723384504335133†L746-L749】.  An instance also needs a **database mirroring endpoint** to accept availability group connections【723384504335133†L755-L757】.
- **Domain membership** – Both Windows nodes and the SQL Server service accounts should be joined to the same Active Directory domain.  You need domain administrator credentials to create cluster objects and SPNs.
- **Firewall & networking** – Configure static IPs or DHCP reservations for each node, cluster name and listener.  Ensure required ports are open (UDP/TCP 3343 for cluster, TCP 1433 for SQL, TCP 5022 for AG endpoints, plus WinRM port 5986).  DNS must resolve hostnames.

### 1.2 Linux/Mac control node

- Install **Ansible 8+** (with Python 3.9+).  Use `pip` or your package manager.
- Install necessary collections:

  ```bash
  ansible-galaxy collection install ansible.windows
  ansible-galaxy collection install community.windows
  ansible-galaxy collection install oatakan.windows_cluster
  ansible-galaxy collection install oatakan.windows_sql_server
  ansible-galaxy collection install lowlydba.sqlserver
  ```

- Configure **WinRM** on each Windows host for Ansible.  The [`winrm.ps1`](https://docs.ansible.com/ansible/latest/user_guide/windows_setup.html#enable-winrm) script can enable the service and HTTPS listener.

### 1.3 Service accounts and shared resources

| Requirement | Notes |
| --- | --- |
| **SQL Server service account** | Use a domain account for each SQL instance.  The account must have `Log on as a service` rights on the Windows hosts.  Using the same account simplifies SPN registration and Kerberos【723384504335133†L710-L717】. |
| **SQL Agent service account** | Domain account with rights to start the Agent. |
| **Cluster file‑share witness** | For a two‑node cluster, configure a **file‑share witness** on a separate server.  Give the Cluster Name Object (CNO) modify permissions on the share【854606560716816†L158-L176】. |
| **Availability group listener IP(s)** | Reserve one or more IP addresses in each subnet for the listener.  Provide DNS registration rights or pre‑create the DNS record. |

## 2 Ansible Inventory and Variables

Create an **inventory** that defines the two Windows nodes and groups them into roles:

```ini
[primary_server]
node1 ansible_host=192.168.1.101 ansible_user=Administrator ansible_password=<vaulted_password> ansible_connection=winrm ansible_port=5986 ansible_winrm_scheme=https

[secondary_server]
node2 ansible_host=192.168.1.102 ansible_user=Administrator ansible_password=<vaulted_password> ansible_connection=winrm ansible_port=5986 ansible_winrm_scheme=https

[all:vars]
dns_domain=example.com
cluster_name=SqlCluster
listener_name=SqlAgListener
listener_ips=["192.168.1.110"]
ag_name=SalesAg
ag_database=SalesDb
sql_instance_name=MSSQLSERVER
sql_svc_account=EXAMPLE\\sqlsvc
sql_svc_password=<vaulted_password>
ag_mode=SynchronousCommit  # or AsynchronousCommit
failover_mode=Automatic    # or Manual
```

Consider storing sensitive values in an **Ansible Vault**.

## 3 Role 1 – Configure the Windows Failover Cluster

The `oatakan.windows_cluster` collection automates WSFC tasks.  Use two plays: one for the **first node** (which creates the cluster) and another for the **additional node**.  The sample playbook in the collection’s README shows this pattern【275136636504550†L69-L104】.

### 3.1 Install prerequisites (if not templated)

If your template does not include the Failover Clustering feature or RSAT tools, install them via `win_feature`:

```yaml
- name: Ensure Failover Clustering feature is installed
  ansible.builtin.win_feature:
    name:
      - Failover-Clustering
      - RSAT-Clustering-Mgmt
      - RSAT-Clustering-PowerShell
    include_management_tools: true
  register: cluster_feature
```

### 3.2 Create the cluster (primary node)

Run the following role on the **primary node** only:

```yaml
- name: Set up cluster on primary node
  hosts: primary_server
  roles:
    - role: oatakan.windows_cluster.failover_cluster
      cluster_name: "{{ cluster_name }}"
      nodes: ["{{ ansible_hostname }}"]
      static_mac: false
      witness: fileShareWitness
      witness_path: "/path/to/share"
```

### 3.3 Add secondary node to cluster

On the secondary node, join it to the existing cluster:

```yaml
- name: Join secondary node to cluster
  hosts: secondary_server
  roles:
    - role: oatakan.windows_cluster.failover_cluster
      cluster_name: "{{ cluster_name }}"
      nodes: ["{{ ansible_hostname }}"]
      static_mac: false
      witness: fileShareWitness
      witness_path: "/path/to/share"
```

## 4 Role 2 – Enable Always‑On Availability Groups on SQL Server

Use the `oatakan.windows_sql_server.alwayson_common` role or `win_dsc` with the SqlServerDsc module to enable the Always‑On feature on each SQL instance.  The role performs registry updates, service restarts and checks the instance status【615704905418228†L23-L33】.

### 4.1 Sample playbook to enable Always‑On

```yaml
- name: Enable Always-On on all SQL servers
  hosts: primary_server:secondary_server
  vars:
    restart_service: true
  roles:
    - role: oatakan.windows_sql_server.alwayson_common
      first_node: "{{ (inventory_hostname in groups['primary_server']) | ternary('true','false') }}"
```

Alternatively, use `win_dsc` to call the `SqlServerDsc::SqlAlwaysOnService` resource to enable Always‑On.  This requires the SqlServerDsc PowerShell module.

## 5 Role 3 – Create the Availability Group

The `oatakan.windows_sql_server.alwayson` role creates the AG and configures replicas.  It supports creating a primary/secondary pair with automatic seeding【875041872307643†L24-L33】.

### 5.1 Prepare databases

Ensure that the database(s) you want to include in the availability group exist on the primary server.  Backup and restore them on the secondary server if necessary.

### 5.2 Sample playbook to create the AG

```yaml
- name: Configure Availability Group on primary server
  hosts: primary_server
  roles:
    - role: oatakan.windows_sql_server.alwayson
      ag_name: "{{ ag_name }}"
      sql_instance_name: "{{ sql_instance_name }}"
      dbs:
        - name: "{{ ag_database }}"
      first_node: true

- name: Configure Availability Group on secondary server
  hosts: secondary_server
  roles:
    - role: oatakan.windows_sql_server.alwayson
      ag_name: "{{ ag_name }}"
      sql_instance_name: "{{ sql_instance_name }}"
      dbs:
        - name: "{{ ag_database }}"
      first_node: false
      sync_type: "Automatic"
```

If you prefer more control, use the `lowlydba.sqlserver.availability_group` module instead.  For example:

```yaml
- name: Create AG using lowlydba module on primary
  hosts: primary_server
  tasks:
    - name: Create AG
      lowlydba.sqlserver.availability_group:
        name: "{{ ag_name }}"
        primary_replica: "{{ inventory_hostname }}"
        replicas:
          - server: "{{ inventory_hostname }}"
            failover_mode: Automatic
            availability_mode: SynchronousCommit
        database: "{{ ag_database }}"
        seeding_mode: Automatic
```

Join the secondary in a separate task.

## 6 Role 4 – Create the Availability Group Listener

To provide a single connection string for clients, create an AG listener using either `oatakan.windows_sql_server.alwayson` (if using that role) or the `lowlydba.sqlserver.ag_listener` module.  Define the listener name, static IP(s) and port【875041872307643†L24-L33】.

### 6.1 Sample playbook to create the listener

```yaml
- name: Create AG listener
  hosts: primary_server
  tasks:
    - name: Create AG listener
      lowlydba.sqlserver.ag_listener:
        name: "{{ listener_name }}"
        availability_group: "{{ ag_name }}"
        ip_addresses: "{{ listener_ips }}"
        port: 1433
```

If you’re using the `oatakan.windows_sql_server.alwayson` role, set `listener_name` and `listener_ip` variables in the role arguments.

## 7 Role 5 – Validation and Failover Testing

After configuration, validate the cluster and AG health using `win_shell` or `dbatools`.  Execute manual failover to ensure it works.

### 7.1 Check AG status

```yaml
- name: Check AG status
  hosts: primary_server:secondary_server
  tasks:
    - name: Invoke dbatools to check status
      win_shell: |
        Import-Module dbatools
        Get-DbaAvailabilityGroup -SqlInstance $env:COMPUTERNAME | Format-Table Name, PrimaryReplica, SynchronizationState
```

### 7.2 Perform manual failover

```yaml
- name: Perform manual failover
  hosts: primary_server
  tasks:
    - name: Failover AG
      win_shell: |
        Import-Module dbatools
        Switch-DbaAvailabilityGroup -Name "{{ ag_name }}" -NewPrimary "{{ hostvars['secondary_server']['inventory_hostname'] }}"
```

Verify that the secondary becomes the primary and clients connect via the listener.

## 8 Best Practices and Considerations

- **Synchronization vs Asynchronous replication** – Use synchronous replication and automatic failover for local HA; asynchronous replication for remote DR.
- **Backups and maintenance** – Even with AGs, continue regular backups and DBCC checks.  Configure secondary replicas as readable for reporting, if needed.
- **Testing** – Regularly test failovers and updates in a non‑production environment.
- **Documentation** – Record all cluster, AG and listener configurations, including service accounts and SPNs.

## Conclusion

By leveraging community Ansible roles and modules, you can automate the end‑to‑end setup of a SQL Server Always‑On Availability Group across two Windows nodes.  Follow the modular role structure—cluster creation, enabling Always‑On, AG creation, listener creation and validation—to ensure a repeatable, idempotent deployment.  Adjust variables and tasks to fit your organisation’s naming conventions, IP addresses and security practices.