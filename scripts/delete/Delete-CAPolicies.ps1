# Delete-CAPolicies.ps1 - Script to delete Conditional Access Policies via GUI or CLI

<#[
.SYNOPSIS
    Delete Conditional Access Policies using Microsoft Graph via GUI or CLI.

.DESCRIPTION
    This script allows you to delete Conditional Access Policies from Microsoft Entra ID. 
    It supports both an interactive GUI for policy selection and deletion, as well as a CLI mode 
    for scripted removal by DisplayName or ID.

.PARAMETER PolicyNames
    Optional. An array of policy display names to delete in CLI mode.

.PARAMETER GUI
    Launches an interactive GUI to select and delete policies.

.EXAMPLE
    .\Delete-CAPolicies.ps1 -PolicyNames "CA01000-Block-LegacyAuth", "CA02000-RequireMFA"

.EXAMPLE
    .\Delete-CAPolicies.ps1 -GUI

.NOTES
   Author: Patrick Seltmann  
   Version: 0.1.0 
   Created: 2025-05-03  
   Prerequisites: 
    - Microsoft.Graph PowerShell SDK
    - PowerShell V7
#>

param (
    [Parameter(Mandatory = $false)]
    [string[]]$PolicyNames,

    [switch]$GUI
)

begin {
    if ($GUI -and $PolicyNames) {
        throw "-GUI cannot be used together with -PolicyNames."
    }

    $RequiredModules = @(
        "Microsoft.Graph.Authentication"
    )
    foreach ($Module in $RequiredModules) {
        if (-not (Get-Module -Name $Module -ListAvailable)) {
            Install-Module $Module -Scope CurrentUser -Force
        }
        Import-Module $Module -Force -Verbose
    }

    try {
        Connect-MgGraph -Scopes 'Policy.ReadWrite.ConditionalAccess' -ErrorAction Stop
    }
    catch {
        Write-Host "Error connecting to Microsoft Graph API: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }

    # === functions ===

    # include functions
    . ".\.\functions\Get-CAPolicies.ps1"
    . ".\.\functions\Remove-CAPolicyById.ps1"
    . ".\.\functions\Load-CAPolicies.ps1"


}

process {
    if ($GUI) {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Delete Conditional Access Policies"
        $form.Size = New-Object System.Drawing.Size(800, 700)
        $form.StartPosition = "CenterScreen"

        $label = New-Object System.Windows.Forms.Label
        $label.Text = "CAxPorter Utility | Select the policies to delete:"
        $label.Location = New-Object System.Drawing.Point(10, 10)
        $label.AutoSize = $true
        $form.Controls.Add($label)

        $listView = New-Object System.Windows.Forms.ListView
        $listView.Location = '10,40'
        $listView.Size = '760,440'
        $listView.View = 'Details'
        $listView.CheckBoxes = $true
        $listView.FullRowSelect = $true
        $listView.Columns.Add("Policy Name", 740) | Out-Null
        $form.Controls.Add($listView)

        $progressBar = New-Object System.Windows.Forms.ProgressBar
        $progressBar.Location = '10,540'
        $progressBar.Size = '760,20'
        $progressBar.Visible = $false
        $form.Controls.Add($progressBar)

        $progressLabel = New-Object System.Windows.Forms.Label
        $progressLabel.Location = '10,565'
        $progressLabel.Size = '760,20'
        $progressLabel.Text = ""
        $form.Controls.Add($progressLabel)

        $btnDelete = New-Object System.Windows.Forms.Button
        $btnDelete.Text = "Delete Selected"
        $btnDelete.Location = '10,500'
        $btnDelete.Size = '120,30'
        $btnDelete.Add_Click({
                $selectedPolicies = @()
                foreach ($item in $listView.CheckedItems) {
                    $selectedPolicies += $item.Tag
                }
            
                if ($selectedPolicies.Count -eq 0) {
                    [System.Windows.Forms.MessageBox]::Show("Please select at least one policy.", "Warning")
                    return
                }
            
                $confirmResult = [System.Windows.Forms.MessageBox]::Show(
                    "Are you sure you want to delete $($selectedPolicies.Count) Conditional Access Policies?",
                    "Confirm Deletion",
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
                if ($confirmResult -ne [System.Windows.Forms.DialogResult]::Yes) {
                    return
                }
            
                $progressBar.Maximum = $selectedPolicies.Count
                $progressBar.Value = 0
                $progressBar.Visible = $true
                $progressLabel.Visible = $true
            
                $counter = 1
                foreach ($policy in $selectedPolicies) {
                    Remove-CAPolicyById -PolicyId $policy.id
                    $progressBar.Value = $counter
                    $progressLabel.Text = "Deleting $counter of $($selectedPolicies.Count) policies..."
                    [System.Windows.Forms.Application]::DoEvents()
                    $counter++
                }
            
                $progressBar.Visible = $false
                $progressLabel.Text = "Done."
                [System.Windows.Forms.Application]::DoEvents()
            
                Start-Sleep -Seconds 3
                [System.Windows.Forms.MessageBox]::Show(
                    "Deletion of $($selectedPolicies.Count) policies completed successfully.",
                    "Done",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
                
                Load-CAPolicies
            })
        $form.Controls.Add($btnDelete)

        $btnReload = New-Object System.Windows.Forms.Button
        $btnReload.Text = "Reload Policies"
        $btnReload.Location = '140,500'
        $btnReload.Size = '120,30'
        $btnReload.Add_Click({
                try {
                    Load-CAPolicies
                }
                catch {
                    [System.Windows.Forms.MessageBox]::Show("Error while reloading policies: $($_.Exception.Message)", "Reload Error")
                }
            })
        $form.Controls.Add($btnReload)

        
        $btnExit = New-Object System.Windows.Forms.Button
        $btnExit.Text = "Exit"
        $btnExit.Location = '270,500'
        $btnExit.Size = '120,30'
        $btnExit.Add_Click({ $form.Close() })
        $form.Controls.Add($btnExit)

        $policies = Get-CAPolicies | Sort-Object DisplayName
        foreach ($policy in $policies) {
            $item = New-Object System.Windows.Forms.ListViewItem($policy.DisplayName)
            $item.Tag = $policy
            $null = $listView.Items.Add($item)
        }

        $form.ShowDialog() | Out-Null
    }
    elseif ($PolicyNames) {
        $allPolicies = Get-CAPolicies
        foreach ($name in $PolicyNames) {
            $policy = $allPolicies | Where-Object { $_.DisplayName -eq $name }
            if ($policy) {
                Remove-CAPolicyById -PolicyId $policy.Id
            }
            else {
                Write-Warning "Policy not found: $name"
            }
        }
    }
    else {
        throw "Either -GUI or -PolicyNames must be specified."
    }
}

end {
    If (-not $Gui) {
        Disconnect-MgGraph
        Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Cyan
    }
}
