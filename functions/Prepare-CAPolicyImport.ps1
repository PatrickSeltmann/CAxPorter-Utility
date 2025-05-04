function Prepare-CAPolicyImport {
    param (
        [Parameter(Mandatory)]
        [object]$Policy,

        [Parameter(Mandatory)]
        [string]$JsonFilePath,

        [Parameter(Mandatory)]
        [string]$PolicyState,

        [string]$CAPolicyPrefix
    )

    if (-not $GUI) {
        Write-Verbose -Verbose -Message "Deploying Conditional Access policy: $($Policy.displayName)"
    }
    
    $Policy.state = $PolicyState
    
    # Remove unneeded properties
    $Policy.PSObject.Properties.Remove('createdDateTime')
    $Policy.PSObject.Properties.Remove('modifiedDateTime')
    $Policy.PSObject.Properties.Remove('id')
    
    
    if ($CAPolicyPrefix) {
        $Policy.DisplayName = "$CAPolicyPrefix$($Policy.DisplayName)"
    }
    
    if ($Policy.Conditions.Users.IncludeGroups) {
        $Policy.Conditions.Users.IncludeGroups = @($Policy.Conditions.Users.IncludeGroups | ForEach-Object { Get-GroupIdByName -GroupName $_ })
    }
    if ($Policy.Conditions.Users.ExcludeGroups) {
        $Policy.Conditions.Users.ExcludeGroups = @($Policy.Conditions.Users.ExcludeGroups | ForEach-Object { Get-GroupIdByName -GroupName $_ })
    }
    
    if ($Policy.Conditions.Users.IncludeRoles) {
        $Policy.Conditions.Users.IncludeRoles = @($Policy.Conditions.Users.IncludeRoles | ForEach-Object {
                $roleId = Get-RoleIdByName $_
                if ($roleId) { $roleId }
            })
    }
    if ($Policy.Conditions.Users.ExcludeRoles) {
        $Policy.Conditions.Users.ExcludeRoles = @($Policy.Conditions.Users.ExcludeRoles | ForEach-Object {
                $roleId = Get-RoleIdByName $_
                if ($roleId) { $roleId }
            })
    }
    
    if ($Policy.GrantControls.authenticationStrength -and $Policy.GrantControls.authenticationStrength.displayName) {
        $authStrengthName = $Policy.GrantControls.authenticationStrength.displayName
        $allowedCombinations = $Policy.GrantControls.authenticationStrength.allowedCombinations
        $authStrengthId = GetOrCreate-AuthenticationStrengthIdByName -AuthStrengthName $authStrengthName -AllowedCombinations $allowedCombinations
        if ($authStrengthId) {
            $Policy.GrantControls.authenticationStrength = @{ id = $authStrengthId }
        }
    }
    
    if ($Policy.Conditions.Applications.includeApplications) {
        $Policy.Conditions.Applications.includeApplications = @(
            $Policy.Conditions.Applications.includeApplications | ForEach-Object {
                $appId = Get-ApplicationIdByName -AppName $_
                if ($appId) {
                    $appId
                }
            }
        )
    }
    
    if ($Policy.Conditions.Applications.excludeApplications) {
        $Policy.Conditions.Applications.excludeApplications = @(
            $Policy.Conditions.Applications.excludeApplications | ForEach-Object {
                $appId = Get-ApplicationIdByName -AppName $_
                if ($appId) {
                    $appId
                }
            }
        )
    }
    
    if ($Policy.GrantControls.termsOfUse) {
        $Policy.GrantControls.termsOfUse = @(
            $Policy.GrantControls.termsOfUse | ForEach-Object {
                $touDisplayName = $_.displayName
                $PdfPath = Join-Path -Path (Split-Path -Path $JsonFilePath -Parent) -ChildPath ("$($touDisplayName).pdf")
                $ToUId = GetOrCreate-TermsOfUse -ToUConfig $_ -PdfFilePath $PdfPath
                if ($ToUId) {
                    Start-Sleep -Seconds 15
                    $ToUId
                }
                else {
                    throw "Error when creating or retrieving the Terms of Use '$touDisplayName'. Import canceled."
                }
            }
        )
    }
    
    if ($Policy.Conditions.Locations.IncludeLocations) {
        $Policy.Conditions.Locations.IncludeLocations = @(
            $Policy.Conditions.Locations.IncludeLocations | ForEach-Object {
                GetOrCreate-NamedLocation -LocationConfig $_
            }
        )
    }
    
    if ($Policy.Conditions.Locations.ExcludeLocations) {
        $Policy.Conditions.Locations.ExcludeLocations = @(
            $Policy.Conditions.Locations.ExcludeLocations | ForEach-Object {
                GetOrCreate-NamedLocation -LocationConfig $_
            }
        )
    }
    
    # Sicherstellen, dass Applications-Objekt vorhanden ist
    if (-not $Policy.Conditions.Applications) {
        $Policy.Conditions.Applications = [PSCustomObject]@{}
    }

    # Authentication Contexts vorbereiten
    if ($Policy.Conditions.Applications.includeAuthenticationContextClassReferences) {
        $acRefs = $Policy.Conditions.Applications.includeAuthenticationContextClassReferences

        # Wenn Objekte mit Metadaten enthalten sind, extrahiere ID und führe ggf. PATCH aus
        if ($acRefs -is [System.Collections.IEnumerable] -and $acRefs[0] -is [psobject] -and $acRefs[0].id) {
            $ids = @()

            foreach ($ac in $acRefs) {
                $id = $ac.id
                $displayName = if ($ac.displayName) { $ac.displayName } else { "Imported Context $id" }
                $description = if ($ac.description) { $ac.description } else { "Imported via CAxPorter" }
                $isAvailable = if ($null -eq $ac.isAvailable -or $ac.isAvailable -eq "") { $true } else { [bool]$ac.isAvailable }

                GetOrCreate-AuthenticationContext -Id $id -DisplayName $displayName -Description $description -IsAvailable $isAvailable

                $ids += $id
            }

            # Für den API-Call nur ID-Array setzen
            $Policy.Conditions.Applications.includeAuthenticationContextClassReferences = $ids
        }

        $Policy.Conditions.Applications.includeApplications = @()
        $Policy.Conditions.Applications.excludeApplications = @()
        
    }

    
    try {
        Write-Host ($Policy | ConvertTo-Json)
        $global:test = $Policy
        $response = Invoke-MgGraphRequest `
            -Method POST `
            -Uri 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies' `
            -Body ($Policy | ConvertTo-Json -Depth 10 -Compress) `
            -ContentType "application/json"
    
        if (-not $GUI) {
            Write-Host "Successfully created: $($Policy.DisplayName)" -ForegroundColor Green
        }
    }
    catch {
        Write-Error -Message "Error while creating rhe policy '$($Policy.DisplayName)': $_"
    }
}