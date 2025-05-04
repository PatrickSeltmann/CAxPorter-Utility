    # Funktion zum Abrufen des Displaynamens einer Rolle anhand der Objekt-ID
    function Get-RoleDisplayName {
        param (
            [string]$RoleId
        )
        try {
            # Zuerst versuchen, den Rollennamen mit Get-MgDirectoryRole abzurufen
            $Role = Get-MgDirectoryRole -Filter "id eq '$RoleId'" -ErrorAction SilentlyContinue
            
            if ($Role) {
                return $Role.DisplayName
            }
            else {
                # Falls Get-MgDirectoryRole kein Ergebnis liefert, Get-MgRoleManagementDirectoryRoleDefinition verwenden
                $RoleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $RoleId -ErrorAction SilentlyContinue
                if ($RoleDefinition) {
                    return $RoleDefinition.DisplayName
                }
                else {
                    Write-Error "Rolle nicht gefunden für RoleId: $RoleId"
                    return $RoleId
                }
            }
        }
        catch {
            Write-Error "Fehler beim Abrufen des Rollennamens für RoleId: $RoleId - $_"
            return $RoleId
        }
    }