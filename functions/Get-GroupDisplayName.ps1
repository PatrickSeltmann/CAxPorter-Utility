    # Funktion zum Abrufen des Displaynamens einer Gruppe anhand der Objekt-ID
    function Get-GroupDisplayName {
        param (
            [string]$GroupId
        )
        try {
            $Group = Get-MgGroup -GroupId $GroupId -ErrorAction Stop
            return $Group.DisplayName
        }
        catch {
            Write-Error "Fehler beim Abrufen des Gruppennamens für GroupId: $GroupId"
            return $GroupId
        }
    }