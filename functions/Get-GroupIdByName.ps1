function Get-GroupIdByName {
    param (
        [string]$GroupName,
        [ValidateSet("v1.0", "beta")]
        [string]$ApiVersion = "v1.0"
    )

    # 1. Gruppe anhand des DisplayNames suchen
    $filter = "displayName eq '$GroupName'"
    $escapedFilter = [uri]::EscapeDataString($filter)
    $uri = "https://graph.microsoft.com/$ApiVersion/groups?`$filter=$escapedFilter"

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
        if ($response.value.Count -gt 0) {
            return $response.value[0].id
        }
    } catch {
        Write-Warning "Fehler beim Abfragen der Gruppe '$GroupName': $_"
    }

    # 2. Gruppe erstellen, wenn sie nicht gefunden wurde
    $newGroupBody = @{
        displayName     = $GroupName
        mailEnabled     = $false
        securityEnabled = $true
        mailNickname    = ($GroupName -replace '\s', '')
        groupTypes      = @()
    }

    try {
        $newGroup = Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/$ApiVersion/groups" `
            -Body ($newGroupBody | ConvertTo-Json -Depth 3) `
            -ContentType "application/json" `
            -OutputType PSObject

        return $newGroup.id
    } catch {
        Write-Warning "Fehler beim Erstellen der Gruppe '$GroupName': $_"
        return $null
    }
}
