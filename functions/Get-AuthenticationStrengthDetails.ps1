# Funktion zum Abrufen der Authentication Strength Konfiguration anhand der Objekt-ID
function Get-AuthenticationStrengthDetails {
    param (
        [string]$AuthStrengthId
    )

    try {
        # Verwende Get-MgPolicyAuthenticationStrengthPolicy, um die Authentication Strength Policy abzurufen
        $AuthStrengthPolicy = Get-MgPolicyAuthenticationStrengthPolicy -AuthenticationStrengthPolicyId $AuthStrengthId -ErrorAction Stop
        return $AuthStrengthPolicy
    }
    catch {
        Write-Error "Fehler beim Abrufen der Authentication Strength Policy für ID: $AuthStrengthId"
        return $AuthStrengthId
    }
}