# Get all servers from your CMS (assuming you have them registered)
# Or just a list for now
$ServerList = Get-Content "C:\Repo\SQL-Cluster-Sentry\inventory.txt"

$InventoryReport = @()

foreach ($Server in $ServerList) {
    try {
        # Run the "Truth Serum" SQL
        $Topology = Invoke-Sqlcmd -ServerInstance $Server -InputFile "C:\Repo\SQL-Cluster-Sentry\Get-SqlTopology.sql" -ErrorAction Stop
        
        $Object = [PSCustomObject]@{
            ServerName      = $Server
            TrueIdentity    = $Topology.ArchitectureType
            CurrentRole     = $Topology.Role
            Partner         = $Topology.FailoverPartner
        }
        
        $InventoryReport += $Object
        Write-Host " [DETECTED] $Server is actually a $($Topology.ArchitectureType)" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not contact $Server. It might be a passive FCI node or offline."
    }
}

# Output the TRUTH, not what SSMS thinks
$InventoryReport | Format-Table -AutoSize