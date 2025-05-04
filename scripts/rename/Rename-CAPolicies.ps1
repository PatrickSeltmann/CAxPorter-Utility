<#
.SYNOPSIS
    Rename Conditional Access Policies using a regular expression pattern, with optional GUI support.

.DESCRIPTION
    This script allows you to rename Conditional Access Policies in Microsoft Entra ID (Azure AD) using a customizable search and replace pattern (Regex).
    You can use either a graphical interface to select and rename policies interactively, or run the script in CLI mode with specified parameters.

    The script supports:
    - Regex-based search and replace
    - GUI for selecting policies and entering pattern
    - Progress bar and status label during rename operation
    - Automatic reloading of updated policy names
    - Dry run option (CLI only)
    - Microsoft Graph integration via the Graph PowerShell SDK

.EXAMPLE
    Launch the GUI to rename Conditional Access Policies:
    PS C:\> .\Rename-CAPolicies.ps1 -GUI

    Starts the graphical interface, allowing selection of policies and entry of regex search and replacement strings.

.EXAMPLE
    Rename all policies containing "[Imported]" in their name, replacing it with an empty string:
    PS C:\> .\Rename-CAPolicies.ps1 -SearchPattern "\[Imported\]" -Replacement ""

    This command will find all Conditional Access Policies where the display name contains "[Imported]" and remove it.

.EXAMPLE
    Perform a dry run to preview renames without applying changes:
    PS C:\> .\Rename-CAPolicies.ps1 -SearchPattern "^CA" -Replacement "Policy-" -DryRun

    Useful to simulate changes before performing an actual rename.

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
    [string]$SearchPattern,

    [Parameter(Mandatory = $false)]
    [string]$Replacement,

    [switch]$DryRun,

    [switch]$GUI
)

begin {
    # === Vorbereitungen ===

    # Parameter prüfen
    if ($GUI -and ($PSBoundParameters.ContainsKey('SearchPattern') -or $PSBoundParameters.ContainsKey('Replacement') -or $DryRun)) {
        throw "Parameter -GUI cannot be used together with -SearchPattern, -Replacement, or -DryRun."
    }

    if (-not $GUI -and (-not $PSBoundParameters.ContainsKey('SearchPattern') -or -not $PSBoundParameters.ContainsKey('Replacement'))) {
        throw "Parameters -SearchPattern and -Replacement are required when not using -GUI."
    }

    # Module prüfen/laden
    $RequiredModules = @(
        "Microsoft.Graph.Authentication"
    )
    foreach ($Module in $RequiredModules) {
        if (-not (Get-Module -Name $Module -ListAvailable)) {
            Install-Module $Module -Scope CurrentUser -Force
        }
        Import-Module $Module -Force -Verbose
    }

    # Verbinde dich mit der Microsoft Graph API und fordere die erforderlichen Berechtigungen an
    try {
        Connect-MgGraph -Scopes 'Policy.ReadWrite.ConditionalAccess' -ErrorAction Stop
    }
    catch {
        Write-Host "Fehler beim Verbinden mit der Microsoft Graph API: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }

    # == Variablen ===
    $global:RenamedPolicies = @()
    
    # === functions ===

    # include functions
    . ".\.\functions\Get-CAPolicies.ps1"
    . ".\.\functions\Rename-CAPolicy.ps1"
    . ".\.\functions\Load-CAPolicies.ps1"

}

process {
    if ($GUI) {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $form = New-Object System.Windows.Forms.Form
        $form.Text = "CAxPorter Utility | Rename Conditional Access Policies"
        $form.Size = New-Object System.Drawing.Size(800, 660)
        $form.StartPosition = "CenterScreen"

        $label1 = New-Object System.Windows.Forms.Label
        $label1.Text = "Search Pattern (Regex):"
        $label1.Location = '10,10'
        $label1.AutoSize = $true
        $form.Controls.Add($label1)

        $txtSearch = New-Object System.Windows.Forms.TextBox
        $txtSearch.Location = '10,30'
        $txtSearch.Size = '760,20'
        $form.Controls.Add($txtSearch)

        $label2 = New-Object System.Windows.Forms.Label
        $label2.Text = "Replacement String:"
        $label2.Location = '10,60'
        $label2.AutoSize = $true
        $form.Controls.Add($label2)

        $txtReplace = New-Object System.Windows.Forms.TextBox
        $txtReplace.Location = '10,80'
        $txtReplace.Size = '760,20'
        $form.Controls.Add($txtReplace)

        $btnSelectAll = New-Object System.Windows.Forms.Button
        $btnSelectAll.Text = "Select All"
        $btnSelectAll.Location = '10,100'
        $btnSelectAll.Size = '100,30'
        $btnSelectAll.Add_Click({ foreach ($item in $listView.Items) { $item.Checked = $true } })
        $form.Controls.Add($btnSelectAll)

        $btnbtnDeselectAll = New-Object System.Windows.Forms.Button
        $btnbtnDeselectAll.Text = "Deselect All"
        $btnbtnDeselectAll.Location = '120,100'
        $btnbtnDeselectAll.Size = '100,30'
        $btnbtnDeselectAll.Add_Click({ foreach ($item in $listView.Items) { $item.Checked = $false } })
        $form.Controls.Add($btnbtnDeselectAll)

        $btnReload = New-Object System.Windows.Forms.Button
        $btnReload.Text = "Reload all Policies"
        $btnReload.Location = '230,100'
        $btnReload.Size = '140,30'
        $btnReload.Add_Click({
                try {
                    Load-CAPolicies -EnableHighlighting
                }
                catch {
                    [System.Windows.Forms.MessageBox]::Show("Error during the reload the policies: $($_.Exception.Message)", "Error")
                }
            })
        $form.Controls.Add($btnReload)

        $btnExit = New-Object System.Windows.Forms.Button
        $btnExit.Text = "Exit"
        $btnExit.Location = '380,100'
        $btnExit.Size = '100,30'
        $btnExit.Add_Click({ $form.Close() })
        $form.Controls.Add($btnExit)

        $progressBar = New-Object System.Windows.Forms.ProgressBar
        $progressBar.Location = '10,540'
        $progressBar.Size = '760,20'
        $progressBar.Minimum = 0
        $progressBar.Maximum = $global:RenamedPolicies.count
        $progressBar.Visible = $false
        $form.Controls.Add($progressBar)

        $progressLabel = New-Object System.Windows.Forms.Label
        $progressLabel.Location = '10,565'
        $progressLabel.Size = '760,20'
        $progressLabel.Text = ""
        $form.Controls.Add($progressLabel)


        $listView = New-Object System.Windows.Forms.ListView
        $listView.Location = '10,140'
        $listView.Size = '760,350'
        $listView.View = 'Details'
        $listView.CheckBoxes = $true
        $listView.FullRowSelect = $true
        $listView.Columns.Add("Policy Name", 740) | Out-Null
        $form.Controls.Add($listView)

        $btnRename = New-Object System.Windows.Forms.Button
        $btnRename.Text = "Rename Policies"
        $btnRename.Location = '10,500'
        $btnRename.Size = '760,30'
        $btnRename.Add_Click({
                $pattern = $txtSearch.Text
                $replacement = $txtReplace.Text
        
                $policiesToRename = @()
                foreach ($item in $listView.CheckedItems) {
                    $policy = $item.Tag
                    if ($policy.DisplayName -match $pattern) {
                        $policiesToRename += $policy
                    }
                }
        
                if ($policiesToRename.Count -eq 0) {
                    [System.Windows.Forms.MessageBox]::Show("No matching policies found for the given pattern.", "Info")
                    return
                }
        
                $progressBar.Value = 0
                $progressBar.Maximum = $policiesToRename.Count
                $progressBar.Visible = $true
                $progressLabel.Text = "Renaming 0 of $($policiesToRename.Count) policies..."
                $progressLabel.Visible = $true
                [System.Windows.Forms.Application]::DoEvents()
        
                $counter = 1
                foreach ($policy in $policiesToRename) {
                    if (Rename-CAPolicy -Policy $policy -SearchPattern $pattern -Replacement $replacement) {
                        $progressBar.Value = $counter
                        $progressLabel.Text = "Renaming $counter of $($policiesToRename.Count) policies..."
                        [System.Windows.Forms.Application]::DoEvents()
                        $counter++
                        Start-Sleep -Seconds 1
                    }
                }
        
                Start-Sleep -Seconds 3
                $progressLabel.Text = "Renaming completed."
                $progressBar.Visible = $false
                [System.Windows.Forms.Application]::DoEvents()
                            
                Load-CAPolicies -EnableHighlighting
            })
        
        
        $form.Controls.Add($btnRename)

        Load-CAPolicies
        $form.ShowDialog() | Out-Null
    }
    else {
        $ConditionalAccessPolicies = Get-CAPolicies
        foreach ($policy in $ConditionalAccessPolicies) {
            Rename-CAPolicy -Policy $policy -SearchPattern $SearchPattern -Replacement $Replacement
        }
    }
}

end {
    if (-not $GUI) {
        Disconnect-MgGraph
        Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Cyan
    }
}