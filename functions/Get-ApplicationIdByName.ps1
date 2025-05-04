    # Funktion zum Abrufen der Application ID anhand des Displaynamens oder Beibehaltung des Aliaswertes
    function Get-ApplicationIdByName {
        param (
            [string]$AppName
        )

        # Liste der bekannten Aliase und ihre zugehörigen App-IDs
        $knownAliases = @(
            'Office365', # Alias für Office 365 Apps
            'MicrosoftAdminPortals'  # Alias für Microsoft Admin Portals
        )

        # Überprüfe, ob der Name ein bekannter Alias ist
        if ($knownAliases -contains $AppName) {
            return $AppName  # Gib den Alias direkt zurück
        }

        # Überprüfe, ob der Name 'All' oder 'None' ist
        if ($AppName -eq 'All' -or $AppName -eq 'None') {
            return $AppName
        }

        try {
            # Versuche, die Application ID anhand des Displaynamens zu ermitteln
            $app = Get-MgApplication -Filter "displayName eq '$AppName'" -ErrorAction SilentlyContinue

            # Fallback zur Suche in Service Principals, falls App nicht gefunden wird
            if (-not $app) {
                $servicePrincipal = Get-MgServicePrincipal -Filter "displayName eq '$AppName'" -ErrorAction SilentlyContinue

                if ($servicePrincipal) {
                    return $servicePrincipal.AppId
                }
                else {
                    throw "ServicePrincipal nicht gefunden für AppName: $AppName"
                }
            }

            return $app.AppId
        }
        catch {
            Write-Host "Warnung: Anwendung mit dem Namen '$AppName' konnte nicht gefunden werden und wird übersprungen." -ForegroundColor Yellow
            return $null
        }
    }