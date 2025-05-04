    # Funktion zum Abrufen der Rolle anhand des Namens
    function Get-RoleIdByName {
        param (
            [string]$RoleName
        )

        $role = Get-MgDirectoryRole -Filter "displayName eq '$RoleName'" -ErrorAction SilentlyContinue
        if ($role -and $role.RoleTemplateId) {
            return $role.RoleTemplateId
        }
        else {
            Write-Host "Fehler: Rolle mit dem Namen '$RoleName' ist keine eingebaute Rolle oder konnte nicht gefunden werden." -ForegroundColor Yellow
            return $null
        }
    }