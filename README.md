# SQL-Cluster-Sentry

### The "Why"
This repository was born from a specific operational failure. In a previous role, a lack of distinction between **Local High Availability (HA)** and **Geographic Disaster Recovery (DR)** led to an accidental failover of a 4.5TB Data Warehouse across a 1GB WAN link. 

The root cause was treating a **Failover Cluster Instance (FCI)** like an **Availability Group (AG)**. 

### The Solution
`SQL-Cluster-Sentry` is a PowerShell-based logic gate designed to be run *before* any automated patching or maintenance cycle. It acts as a "Traffic Cop" for the cluster.

### Core Logic
The script performs a **Topology Audit** before allowing a move:
1.  **Who am I?** Determines if the instance is an FCI (Shared Storage) or AG (Replicated Storage).
2.  **Where is my partner?** Compares the Active Node's Subnet/Site against the Target Node.
3.  **The "Kill Switch":** * IF `InstanceType == FCI` 
    * AND `SourceSubnet != TargetSubnet` 
    * THEN **BLOCK FAILOVER**.

### Intended Workflow
1.  **MECM/SCCM** triggers the maintenance window.
2.  `Test-SqlFailoverSafety.ps1` runs.
3.  If returns **TRUE**: Proceed with standard Cluster-Aware Update.
4.  If returns **FALSE**: Abort patch on this node. Alert SysAdmin. **Do Not Move Data.**

### Philosophy
"Automation without Context is just automated destruction." - Gavin Dobbs
