function GetOrCreate-AuthenticationContext {
    param (
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter()]
        [string]$DisplayName = "Imported Context $Id",

        [Parameter()]
        [string]$Description = "Imported via CAxPorter",

        [Parameter()]
        [bool]$IsAvailable = $true
    )

    $uri = "https://graph.microsoft.com/beta/identity/conditionalAccess/authenticationContextClassReferences/$Id"

    try {
        $existing = Invoke-MgGraphRequest -Method GET -Uri $uri
        return $existing
    }
    catch {
        Write-Verbose "Authentication Context '$Id' does not exist or could not be retrieved. Attempting to create or patch..."

        $body = @{
            displayName = $DisplayName
            description = $Description
            isAvailable = $IsAvailable
        }

        try {
            Invoke-MgGraphRequest -Method PATCH -Uri $uri -Body ($body | ConvertTo-Json -Depth 3 -Compress) -ContentType "application/json"
            return @{
                id = $Id
                displayName = $DisplayName
                description = $Description
                isAvailable = $IsAvailable
            }
        }
        catch {
            throw "Failed to create or update Authentication Context '$Id': $_"
        }
    }
}
