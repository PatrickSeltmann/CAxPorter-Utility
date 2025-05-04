 # Funktion zum Abrufen der Authentication Strength anhand des Namens
 function Get-AuthenticationStrengthIdByName {
    param (
        [string]$AuthStrengthName
    )

    $authStrength = Get-MgPolicyAuthenticationStrengthPolicy -Filter "displayName eq '$AuthStrengthName'" -ErrorAction SilentlyContinue
    if ($authStrength) {
        return $authStrength.Id
    }
    else {
        Write-Host "Fehler: Authentication Strength mit dem Namen '$AuthStrengthName' konnte nicht gefunden werden." -ForegroundColor Yellow
        return $null
    }
}