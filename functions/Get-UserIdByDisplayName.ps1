function Get-UserIdByDisplayName {
    param (
        [Parameter(Mandatory)]
        [string]$DisplayName,

        [ValidateSet("v1.0", "beta")]
        [string]$ApiVersion = "v1.0"
    )

    # Sonderbehandlung für 'All'
    if ($DisplayName -eq 'All') {
        return $DisplayName
    }

    # Filter definieren und URL escapen
    $filter = "displayName eq '$DisplayName'"
    $escapedFilter = [uri]::EscapeDataString($filter)
    $uri = "https://graph.microsoft.com/$ApiVersion/users?`$filter=$escapedFilter"

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

        if ($response.value.Count -gt 0) {
            return $response.value[0].id
        } else {
            Write-Warning "Benutzer mit DisplayName '$DisplayName' nicht gefunden."
            return $null
        }
    }
    catch {
        Write-Warning "Fehler beim Auflösen des Benutzers '$DisplayName': $_"
        return $null
    }
}
