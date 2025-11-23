Prompt for Generating Ansible Roles and Playbooks for SQL Server Always-On Setup

You are tasked with creating Ansible roles and playbooks to automatically install and configure a two-node SQL Server Always-On Availability Group on Windows using Ansible. Use the following context and requirements:
	•	Environment: Two Windows Server 2022 nodes with the Failover Clustering feature installed (but not yet configured); SQL Server 2022 Enterprise Edition installed as the default instance; and a Linux or macOS control node running Ansible 8+ configured with WinRM to reach the Windows hosts.
	•	Domain and service accounts: Both Windows nodes are joined to the same Active Directory domain. A domain service account is available for the SQL Server service, with the appropriate permissions and SPNs registered for the virtual network name (VNN) of the availability group listener.
	•	Network and firewall: Configure static IPs or DHCP reservations for each node, the cluster, and the availability group listener. Ensure required ports are open (UDP/TCP 3343 for clustering, TCP 1433 for SQL Server, TCP 5022 for availability group endpoints, and WinRM 5986). DNS must resolve all hostnames.

Your deliverables should include:
	1.	Ansible inventory defining the primary and secondary Windows nodes with WinRM connection details. Include group variables for the cluster name, listener name, listener IP addresses, availability group name, database name, SQL instance name, SQL service account credentials, synchronization mode, and failover mode.
	2.	Role to configure the Windows Server Failover Cluster: install clustering features if missing; create the cluster on the primary node; add the secondary node to the cluster; configure quorum using a file-share witness; and ensure tasks are idempotent.
	3.	Role or tasks to enable the Always-On Availability Groups feature in SQL Server on each node (modify registry settings and restart the SQL service as needed).
	4.	Role or tasks to create the availability group: on the primary node, create the availability group with the specified database(s); join the secondary node as a replica using automatic seeding or manual backup/restore; and set the failover mode (automatic or manual) and synchronization mode (synchronous or asynchronous) as required.
	5.	Role or tasks to create the availability group listener with a specified name, static IP address(es), and port.
	6.	Validation tasks to verify cluster and availability group health and optionally perform a manual failover to test the configuration.
	7.	Use community collections and modules such as oatakan.windows_cluster, oatakan.windows_sql_server.alwayson_common, and lowlydba.sqlserver where appropriate. Follow best practices for idempotent Ansible tasks and secure variable management (e.g., use Ansible Vault for sensitive credentials).

generate the required Ansible roles and playbooks based on the above context and deliverables.