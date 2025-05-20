    # Funktion zum Abrufen des Displaynamens eines Benutzers anhand der Objekt-ID
    function Get-UserDisplayName {
    param (
        [Parameter(Mandatory)]
        [string]$UserId,

        [ValidateSet("v1.0", "beta")]
        [string]$ApiVersion = "v1.0"
    )

    # Spezielle Behandlung für 'All'
    if ($UserId -eq 'All') {
        return $UserId
    }

    $uri = "https://graph.microsoft.com/$ApiVersion/users/$UserId"

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
        return $response.displayName
    }
    catch {
        Write-Warning "Fehler beim Abrufen des Benutzernamens für UserId: $UserId - $_"
        return $UserId
    }
}
