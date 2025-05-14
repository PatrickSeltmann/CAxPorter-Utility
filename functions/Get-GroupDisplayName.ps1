function Get-GroupDisplayName {
    param (
        [string]$GroupId,
        [ValidateSet("v1.0", "beta")]
        [string]$ApiVersion = "v1.0"
    )

    $uri = "https://graph.microsoft.com/$ApiVersion/groups/$GroupId"

    try {
        $group = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
        return $group.displayName
    }
    catch {
        Write-Error "Fehler beim Abrufen des Gruppennamens für GroupId: $GroupId. $_"
        return $GroupId
    }
}