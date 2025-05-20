    # Funktion zum Abrufen des Displaynamens einer Rolle anhand der Objekt-ID
function Get-RoleDisplayName {
    param (
        [Parameter(Mandatory)]
        [string]$RoleId,

        [ValidateSet("v1.0", "beta")]
        [string]$ApiVersion = "v1.0"
    )

    $uri = "https://graph.microsoft.com/$ApiVersion/roleManagement/directory/roleDefinitions/$RoleId"

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
        return $response.displayName
    } catch {
        Write-Warning "Fehler beim Abrufen der Rolle mit ID '$RoleId': $_"
        return $null
    }
}
