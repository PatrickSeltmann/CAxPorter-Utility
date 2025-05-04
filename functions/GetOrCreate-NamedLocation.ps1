    #Funktion zum Abrufen oder Erstellen von Named Locations Konfigurationen
    function GetOrCreate-NamedLocation {
        param(
            [Parameter(Mandatory = $true)]
            [PSObject]$LocationConfig
        )
    
        # Built-in Locations („All“) einfach zurückgeben
        if ($LocationConfig.id -eq "All") {
            return "All"
        }
    
        # Vorhandene Locations abfragen
        $existingLocations = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/namedLocations").value
        $existingLocation = $existingLocations | Where-Object { $_.displayName -eq $LocationConfig.displayName }
    
        if ($existingLocation) {
            If (-not $GUI) {Write-Host "Location '$($LocationConfig.displayName)' already exists." -ForegroundColor Cyan}
            return $existingLocation.id
        }
    
        Write-Host "Erstelle Location '$($LocationConfig.displayName)' neu..." -ForegroundColor Yellow
    
        # Location-Erstellung vorbereiten
        $body = @{
            displayName = $LocationConfig.displayName
        }
    
        switch ($LocationConfig.locationType) {
            "ipNamedLocation" {
                $body["@odata.type"] = "#microsoft.graph.ipNamedLocation"
                $body.ipRanges = $LocationConfig.ipRanges
                $body.isTrusted = $LocationConfig.isTrusted
            }
            "countryNamedLocation" {
                $body["@odata.type"] = "#microsoft.graph.countryNamedLocation"
                $body.countriesAndRegions = $LocationConfig.countriesAndRegions
                $body.includeUnknownCountriesAndRegions = $LocationConfig.includeUnknownCountriesAndRegions
            }
            "compliantNetworkNamedLocation" {
                $body["@odata.type"] = "#microsoft.graph.compliantNetworkNamedLocation"
            }
            Default {
                throw "Unbekannter LocationType: $($LocationConfig.locationType)"
            }
        }
    
        try {
            # Neue Location erstellen
            $newLocation = Invoke-MgGraphRequest `
                -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/namedLocations" `
                -Method POST `
                -Body ($body | ConvertTo-Json -Depth 10 -Compress) `
                -ContentType "application/json"
    
            Write-Host "Location '$($LocationConfig.displayName)' erfolgreich erstellt. Warte auf Replikation..." -ForegroundColor Green
    
            # Wartezeit einfügen (mind. 15 Sekunden empfohlen!)
            Start-Sleep -Seconds 15
    
            return $newLocation.id
        }
        catch {
            $errorDetails = $_.Exception.Response.Content.ReadAsStringAsync().Result
            Write-Error "API-Fehler beim Erstellen der Location: $errorDetails"
            return $null
        }
    } 