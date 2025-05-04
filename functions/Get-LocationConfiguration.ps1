    # Erweitere Funktion zum Abrufen der vollständigen Location-Konfiguration
    function Get-LocationConfiguration {
        param (
            [string]$LocationId
        )

        # Direkt zurückgeben bei Sonderfällen "All", "None"
        if ($LocationId -in @('All', 'None')) {
            return @{ 
                id           = $LocationId
                displayName  = $LocationId
                locationType = 'builtIn'
            }
        }

        try {
            $Location = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/namedLocations/$LocationId" -Method GET -ErrorAction Stop

            # Aufbereitung der vollständigen Location-Konfiguration
            $LocationDetails = @{
                id           = $Location.id
                displayName  = $Location.displayName
                locationType = $Location.'@odata.type' -replace '#microsoft.graph.', ''
            }

            # Erweiterung abhängig vom Location-Typ
            switch ($LocationDetails.locationType) {
                'countryNamedLocation' {
                    $LocationDetails.countriesAndRegions = $Location.countriesAndRegions
                    $LocationDetails.includeUnknownCountriesAndRegions = $Location.includeUnknownCountriesAndRegions
                }
                'ipNamedLocation' {
                    $LocationDetails.isTrusted = $Location.isTrusted
                    $LocationDetails.ipRanges = $Location.ipRanges
                }
            }

            return $LocationDetails
        }
        catch {
            Write-Error "Fehler beim Abrufen der Location-Konfiguration für ID: $LocationId - $_"
            return @{ id = $LocationId; displayName = $LocationId; locationType = 'unknown' }
        }
    }