    # Funktion zum Abrufen des Displaynamens einer Anwendung anhand der Objekt-ID
    function Get-ApplicationDisplayName {
        param (
            [string]$AppId
        )

        # Überprüfe, ob AppId spezielle bekannte Werte enthält
        $knownAliases = @(
            'Office365', # Alias für Office 365 Apps
            'MicrosoftAdminPortals'  # Alias für Microsoft Admin Portals
        )

        if ($knownAliases -contains $AppId) {
            return $AppId  # Gib den bekannten Alias direkt zurück
        }

        if ($AppId -eq $null -or $AppId -eq '' -or $AppId -eq 'None') {
            return 'None'
        }

        # Falls AppId "All" ist, direkt zurückgeben
        if ($AppId -eq 'All') {
            return $AppId
        }

        try {
            # Versuche, den Anwendungsnamen über Get-MgApplication abzurufen
            $App = Get-MgApplication -ApplicationId $AppId -ErrorAction Stop
            return $App.DisplayName
        }
        catch {
                    
            try {
                # Fallback: Versuche den Namen aus den Enterprise Applications (ServicePrincipals) abzurufen
                $ServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$AppId'" -ErrorAction Stop
                if ($ServicePrincipal) {
                    return $ServicePrincipal.DisplayName
                }
                else {
                    throw "ServicePrincipal nicht gefunden für AppId: $AppId"
                }
            }
            catch {
                Write-Error "Fehler beim Abrufen des Anwendungsnamens für AppId: $AppId"
                return $AppId
            }
        }
    }