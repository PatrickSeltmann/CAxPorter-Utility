  # Funktion zum Abrufen der Authentication Strength anhand des Namens oder zur Erstellung, wenn nicht vorhanden
  function GetOrCreate-AuthenticationStrengthIdByName {
    param (
        [string]$AuthStrengthName,
        [string[]]$AllowedCombinations
    )

    $authStrength = Get-MgPolicyAuthenticationStrengthPolicy -Filter "displayName eq '$AuthStrengthName'" -ErrorAction SilentlyContinue
    if ($authStrength) {
        return $authStrength.Id
    }
    else {
        Write-Host "Authentication Strength mit dem Namen '$AuthStrengthName' konnte nicht gefunden werden. Erstelle neue Authentication Strength..." -ForegroundColor Yellow

        try {
            # Erstelle eine neue Authentication Strength Policy
            $newAuthStrength = New-MgPolicyAuthenticationStrengthPolicy -DisplayName $AuthStrengthName -AllowedCombinations $AllowedCombinations -PolicyType "custom" -ErrorAction Stop
            return $newAuthStrength.Id
        }
        catch {
            Write-Host "Fehler beim Erstellen der Authentication Strength '$AuthStrengthName': $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    }
}