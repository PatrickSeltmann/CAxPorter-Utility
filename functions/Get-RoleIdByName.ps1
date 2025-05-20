    # Funktion zum Abrufen der Rolle anhand des Namens
  function Get-RoleIdByName {
    param (
        [Parameter(Mandatory)]
        [string]$RoleName,

        [ValidateSet("v1.0", "beta")]
        [string]$ApiVersion = "v1.0"
    )

    $filter = "displayName eq '$RoleName'"
    $escapedFilter = [uri]::EscapeDataString($filter)
    $uri = "https://graph.microsoft.com/$ApiVersion/roleManagement/directory/roleDefinitions?`$filter=$escapedFilter"

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
        if ($response.value.Count -gt 0) {
            return $response.value[0].id
        }
        else {
            Write-Host "Fehler: Rolle mit dem Namen '$RoleName' konnte nicht gefunden werden." -ForegroundColor Yellow
            return $null
        }
    } catch {
        Write-Warning "Fehler beim Abrufen der Rolle '$RoleName': $_"
        return $null
    }
}
