    # Funktion zum Abrufen des Displaynamens eines Benutzers anhand der Objekt-ID
    function Get-UserDisplayName {
        param (
            [string]$UserId
        )

        # Spezielle Behandlung für 'All'
        if ($UserId -eq 'All') {
            return $UserId  # Gib 'All' direkt zurück
        }

        try {
            $User = Get-MgUser -UserId $UserId -ErrorAction Stop
            return $User.DisplayName
        }
        catch {
            Write-Error "Fehler beim Abrufen des Benutzernamens für UserId: $UserId"
            return $UserId
        }
    }