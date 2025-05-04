function Resolve-CAPolicyReferences {
    param (
        [object]$Policy
    )

    $Policy.PSObject.Properties.Remove('Id')

    if ($Policy.GrantControls.authenticationStrength) {
        $authStrengthId = [string]$Policy.GrantControls.authenticationStrength.id
        $authStrengthDetails = Get-AuthenticationStrengthDetails -AuthStrengthId $authStrengthId
        $Policy.GrantControls.authenticationStrength = @{
            id                    = $authStrengthDetails.id
            displayName           = $authStrengthDetails.displayName
            allowedCombinations   = $authStrengthDetails.allowedCombinations
            requirementsSatisfied = $authStrengthDetails.requirementsSatisfied
        }
    }

    if ($Policy.Conditions.Users.IncludeGroups) {
        $Policy.Conditions.Users.IncludeGroups = @($Policy.Conditions.Users.IncludeGroups | ForEach-Object {
                Get-GroupDisplayName $_
            })
    }
    if ($Policy.Conditions.Users.ExcludeGroups) {
        $Policy.Conditions.Users.ExcludeGroups = @($Policy.Conditions.Users.ExcludeGroups | ForEach-Object {
                Get-GroupDisplayName $_
            })
    }

    if ($Policy.Conditions.Users.IncludeUsers) {
        $Policy.Conditions.Users.IncludeUsers = @($Policy.Conditions.Users.IncludeUsers | ForEach-Object {
                Get-UserDisplayName $_
            })
    }
    if ($Policy.Conditions.Users.ExcludeUsers) {
        $Policy.Conditions.Users.ExcludeUsers = @($Policy.Conditions.Users.ExcludeUsers | ForEach-Object {
                Get-UserDisplayName $_
            })
    }

    if ($Policy.Conditions.Users.IncludeRoles) {
        $Policy.Conditions.Users.IncludeRoles = @($Policy.Conditions.Users.IncludeRoles | ForEach-Object {
                Get-RoleDisplayName $_
            })
    }
    if ($Policy.Conditions.Users.ExcludeRoles) {
        $Policy.Conditions.Users.ExcludeRoles = @($Policy.Conditions.Users.ExcludeRoles | ForEach-Object {
                Get-RoleDisplayName $_
            })
    }

    if ($Policy.Conditions.Applications.IncludeApplications) {
        $Policy.Conditions.Applications.IncludeApplications = @($Policy.Conditions.Applications.IncludeApplications | ForEach-Object {
                $appName = Get-ApplicationDisplayName $_
                if ($appName -eq 'None') { 'None' } else { $appName }
            })
    }

    if ($Policy.Conditions.Applications.ExcludeApplications) {
        $Policy.Conditions.Applications.ExcludeApplications = @($Policy.Conditions.Applications.ExcludeApplications | ForEach-Object {
                $appName = Get-ApplicationDisplayName $_
                if ($appName -eq 'None') { 'None' } else { $appName }
            })
    }

    if ($Policy.Conditions.ExternalTenants) {
        $externalTenants = $Policy.Conditions.ExternalTenants
        if ($externalTenants.'@odata.type' -eq "#microsoft.graph.conditionalAccessAllExternalTenants") {
            $Policy.Conditions.ExternalTenants = @{
                MembershipKind = $externalTenants.membershipKind
                AllTenants     = $true
            }
        }
        elseif ($externalTenants.'@odata.type' -eq "#microsoft.graph.conditionalAccessEnumeratedExternalTenants") {
            $Policy.Conditions.ExternalTenants = @{
                MembershipKind = $externalTenants.membershipKind
                TenantIds      = $externalTenants.TenantIds
            }
        }
    }

    if ($Policy.GrantControls.termsOfUse -and $Policy.GrantControls.termsOfUse.Count -gt 0) {
        $Policy.GrantControls.termsOfUse = @(
            $Policy.GrantControls.termsOfUse | ForEach-Object {
                Get-TermsOfUseConfiguration $_
            }
        )
    }

    if ($Policy.Conditions.Locations) {
        if ($Policy.Conditions.Locations.IncludeLocations) {
            $Policy.Conditions.Locations.IncludeLocations = @(
                $Policy.Conditions.Locations.IncludeLocations | ForEach-Object {
                    Get-LocationConfiguration $_
                }
            )
        }
        if ($Policy.Conditions.Locations.ExcludeLocations) {
            $Policy.Conditions.Locations.ExcludeLocations = @(
                $Policy.Conditions.Locations.ExcludeLocations | ForEach-Object {
                    Get-LocationConfiguration $_
                }
            )
        }
    }

    if ($Policy.Conditions.Applications.includeAuthenticationContextClassReferences) {
        $authContexts = $Policy.Conditions.Applications.includeAuthenticationContextClassReferences
    
        $Policy.Conditions.Applications.includeAuthenticationContextClassReferences = @(
            $authContexts | ForEach-Object {
                $resolved = GetOrCreate-AuthenticationContext -Id $_
                if ($resolved) {
                    [PSCustomObject]@{
                        id          = $resolved.id
                        displayName = $resolved.displayName
                        description = $resolved.description
                        isAvailable = $resolved.isAvailable
                    }
                }
                else {
                    @{ id = $_ }
                }
            }
        )
    
        # Falls includeApplications nicht gesetzt oder leer: auf "none" setzen
        if (-not $Policy.Conditions.Applications.includeApplications -or
            $Policy.Conditions.Applications.includeApplications.Count -eq 0) {
            $Policy.Conditions.Applications.includeApplications = @("none")
        }
    }

    return $Policy
}