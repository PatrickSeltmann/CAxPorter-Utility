    # Funktion zur Überprüfung und Erstellung von Gruppen
    function Get-GroupIdByName {
        param (
            [string]$GroupName
        )
        $group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction SilentlyContinue
        if ($group) {
            return $group.Id
        }
        else {
            # Erstelle die Gruppe, wenn sie nicht existiert
            $newGroup = New-MgGroup -DisplayName $GroupName -MailEnabled:$false -SecurityEnabled:$true -MailNickname $GroupName.Replace(" ", "")
            return $newGroup.Id
        }
    }