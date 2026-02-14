/*
    Name: Get-SqlTopology.sql
    Author: Gavin Dobbs
    Description: Forces the SQL Engine to self-identify as FCI, AG, or Standalone.
    Fixes the "SSMS Blindness" where CMS reports clusters as single nodes.
*/

SET NOCOUNT ON;

DECLARE @IsFCI INT = CAST(SERVERPROPERTY('IsClustered') AS INT);
DECLARE @IsHADR INT = CAST(SERVERPROPERTY('IsHadrEnabled') AS INT);
DECLARE @ServerName NVARCHAR(128) = @@SERVERNAME;
DECLARE @ClusterName NVARCHAR(128) = ISNULL(SERVERPROPERTY('ComputerNamePhysicalNetBIOS'), 'Standalone');

-- 1. Create a Temp Table to hold the "Truth"
DECLARE @Topology TABLE (
    ServerName NVARCHAR(128),
    ArchitectureType NVARCHAR(50), -- 'Standalone', 'FCI', 'AG', 'FCI-in-AG'
    Role NVARCHAR(50),             -- 'Primary', 'Secondary', 'Active', 'Passive', 'N/A'
    FailoverPartner NVARCHAR(128)
);

-- 2. LOGIC GATE: CHECK FOR FCI (Shared Storage)
IF @IsFCI = 1
BEGIN
    INSERT INTO @Topology (ServerName, ArchitectureType, Role, FailoverPartner)
    SELECT 
        @ServerName,
        CASE WHEN @IsHADR = 1 THEN 'FCI-in-AG' ELSE 'FCI' END,
        'Active Owner', -- If we are running this query, we are the active node
        (SELECT TOP 1 NodeName FROM sys.dm_os_cluster_nodes WHERE NodeName <> SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))
END

-- 3. LOGIC GATE: CHECK FOR AG (Shared Nothing / Replicated)
ELSE IF @IsHADR = 1
BEGIN
    -- complex check to see if we are Primary or Secondary
    INSERT INTO @Topology (ServerName, ArchitectureType, Role, FailoverPartner)
    SELECT 
        @ServerName,
        'Availability Group',
        ars.role_desc,
        (SELECT TOP 1 replica_server_name FROM sys.availability_replicas WHERE replica_server_name <> @ServerName)
    FROM sys.dm_hadr_availability_replica_states ars
    JOIN sys.availability_replicas ar ON ars.replica_id = ar.replica_id
    WHERE ar.replica_server_name = @ServerName
END

-- 4. FALLBACK: STANDALONE
ELSE
BEGIN
    INSERT INTO @Topology (ServerName, ArchitectureType, Role, FailoverPartner)
    VALUES (@ServerName, 'Standalone', 'Standalone', 'None')
END

-- 5. THE OUTPUT (The "Massage")
SELECT * FROM @Topology;