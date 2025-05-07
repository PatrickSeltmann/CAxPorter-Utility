<#
.SYNOPSIS
    Exports Conditional Access Policies from Microsoft Entra ID (Azure AD) as JSON files.

.DESCRIPTION
    This PowerShell script connects to the Microsoft Graph API and exports existing Conditional Access Policies 
    into a specified directory as JSON files. It supports both a graphical user interface (GUI) and 
    command-line interface (CLI) for filtering and managing the export process.

    Features include:
    - Export all or filtered Conditional Access Policies using prefix or regex
    - Resolve object references (groups, users, roles, applications) into display names
    - Extend policies with Authentication Strengths, Named Locations, Terms of Use, and Authentication Contexts
    - Optional: Automatically generate technical Markdown documentation using the OpenAI API
    - GUI mode with multi-select and directory selection

.PARAMETER CAPolicyPrefix
    Optional: Filters policies by a display name prefix.
    Cannot be used together with -CAPolicyPattern.

.PARAMETER CAPolicyPattern
    Optional: Filters policies using a regular expression.
    Cannot be used together with -CAPolicyPrefix.

.PARAMETER OutputDir
    Directory where exported JSON (and optionally Markdown) files are stored. Required in CLI mode.

.PARAMETER OpenAIKey
    Optional: A valid OpenAI API key for generating Markdown documentation for exported policies.
    Markdown files will be saved in the same directory as the JSON files.

.PARAMETER GUI
    Enables the graphical user interface (GUI) for selecting policies and an export directory.
    Cannot be used with -CAPolicyPrefix, -CAPolicyPattern, or -OpenAIKey.

.EXAMPLE
    Export all policies to a target directory:
    PS C:\> .\Export-CAPolicies.ps1 -OutputDir .\CAPolicies

.EXAMPLE
    Export policies with prefix "CA100":
    PS C:\> .\Export-CAPolicies.ps1 -OutputDir .\CAPolicies -CAPolicyPrefix "CA100"

.EXAMPLE
    Export policies using regex:
    PS C:\> .\Export-CAPolicies.ps1 -OutputDir .\CAPolicies -CAPolicyPattern "^Admin-.*"

.EXAMPLE
    Export including Markdown documentation via OpenAI:
    PS C:\> .\Export-CAPolicies.ps1 -OutputDir .\CAPolicies -OpenAIKey "<your-API-key>"

.EXAMPLE
    Launch the GUI:
    PS C:\> .\Export-CAPolicies.ps1 -GUI

.NOTES
    Author: Patrick Seltmann  
    Version: 0.1.0 
    Created: 2025-05-03  
    Prerequisites: 
    - Microsoft.Graph PowerShell SDK
    - PowerShell V7
#>


param (
    [Parameter()]
    [string]$CAPolicyPrefix = '*',

    [Parameter()]
    [string]$CAPolicyPattern = '',

    [Parameter()]
    [string]$OpenAIKey,

    [Parameter()]
    [switch]$GUI, 

    [Parameter()]
    [string]$OutputDir
)

begin {
    # # Check CLI parameters and enforce exclusivity
    if ($GUI -and ($PSBoundParameters.ContainsKey('CAPolicyPrefix') -or $PSBoundParameters.ContainsKey('CAPolicyPattern') -or $PSBoundParameters.ContainsKey('OpenAIKey'))) {
        Throw "The -GUI parameter must not be combined with -CAPolicyPrefix, -CAPolicyPattern or -OpenAIKey."
    }
    
    if (-not $GUI -and -not $PSBoundParameters.ContainsKey('OutputDir')) {
        throw "The -OutputDir parameter is required if -GUI is not used."
    }
    if (-not $GUI) {
        if (-Not (Test-Path -Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir
        }
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

    # Connect to Microsoft Graph with necessary scopes
    try {
        Connect-MgGraph -Scopes `
            'Policy.Read.All', `
            'Agreement.ReadWrite.All', `
            'Agreement.Read.All', `
            'Policy.Read.All', `
            'Group.Read.All', `
            'Application.Read.All', `
            'Directory.Read.All'
    }
    catch {
        Write-Host "Error connecting to Microsoft Graph API: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }

    # Load external helper functions files
    . ".\.\functions\Resolve-CAPolicyReferences.ps1"
    . ".\.\functions\Get-AuthenticationStrengthDetails.ps1"
    . ".\.\functions\Get-TermsOfUseConfiguration.ps1"
    . ".\.\functions\Get-LocationConfiguration.ps1"   
    . ".\.\functions\GetOrCreate-AuthenticationContext.ps1"
    . ".\.\functions\Request-OpenAIMarkdown.ps1"
    . ".\.\functions\Get-GroupDisplayName.ps1"
    . ".\.\functions\Get-UserDisplayName.ps1"
    . ".\.\functions\Get-RoleDisplayName.ps1"
    . ".\.\functions\Get-ApplicationDisplayName.ps1"

}

process {
    try {
        
        if ($GUI) {
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing

            $form = New-Object System.Windows.Forms.Form
            $form.Text = "CAxPorter Utility | Export Conditional Access Policies"
            $form.Size = New-Object System.Drawing.Size(800, 700)
            $form.StartPosition = "CenterScreen"

            $label = New-Object System.Windows.Forms.Label
            $label.Text = "Select Conditional Access Policies:"
            $label.Location = New-Object System.Drawing.Point(10, 10)
            $form.Controls.Add($label)

            $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
            $checkedListBox.Location = New-Object System.Drawing.Point(10, 40)
            $checkedListBox.Size = New-Object System.Drawing.Size(760, 360)
            $checkedListBox.CheckOnClick = $true
            $form.Controls.Add($checkedListBox)

            $btnSelectAll = New-Object System.Windows.Forms.Button
            $btnSelectAll.Text = "Select All"
            $btnSelectAll.Location = New-Object System.Drawing.Point(10, 410)
            $btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
            $btnSelectAll.Add_Click({ for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) { $checkedListBox.SetItemChecked($i, $true) } })
            $form.Controls.Add($btnSelectAll)

            $btnDeselectAll = New-Object System.Windows.Forms.Button
            $btnDeselectAll.Text = "Deselect All"
            $btnDeselectAll.Location = New-Object System.Drawing.Point(140, 410)
            $btnDeselectAll.Size = New-Object System.Drawing.Size(120, 30)
            $btnDeselectAll.Add_Click({ for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) { $checkedListBox.SetItemChecked($i, $false) } })
            $form.Controls.Add($btnDeselectAll)

            $folderLabel = New-Object System.Windows.Forms.Label
            $folderLabel.Text = "Output directory:"
            $folderLabel.Location = New-Object System.Drawing.Point(10, 455)
            $form.Controls.Add($folderLabel)

            $textBox = New-Object System.Windows.Forms.TextBox
            $textBox.Location = New-Object System.Drawing.Point(130, 455)
            $textBox.Size = New-Object System.Drawing.Size(500, 20)
            $form.Controls.Add($textBox)

            $btnBrowse = New-Object System.Windows.Forms.Button
            $btnBrowse.Text = "Browse..."
            $btnBrowse.Location = New-Object System.Drawing.Point(640, 453)
            $btnBrowse.Size = New-Object System.Drawing.Size(90, 25)
            $btnBrowse.Add_Click({ $dialog = New-Object System.Windows.Forms.FolderBrowserDialog; if ($dialog.ShowDialog() -eq "OK") { $textBox.Text = $dialog.SelectedPath } })
            $form.Controls.Add($btnBrowse)

            $docCheckBox = New-Object System.Windows.Forms.CheckBox
            $docCheckBox.Text = "Generate Markdown documentation via OpenAI"
            $docCheckBox.Location = New-Object System.Drawing.Point(10, 490)
            $docCheckBox.AutoSize = $true
            $form.Controls.Add($docCheckBox)

            $keyLabel = New-Object System.Windows.Forms.Label
            $keyLabel.Text = "OpenAI API Key:"
            $keyLabel.Location = New-Object System.Drawing.Point(10, 515)
            $form.Controls.Add($keyLabel)

            $keyBox = New-Object System.Windows.Forms.TextBox
            $keyBox.Location = New-Object System.Drawing.Point(130, 515)
            $keyBox.Size = New-Object System.Drawing.Size(500, 20)
            $keyBox.UseSystemPasswordChar = $true
            $form.Controls.Add($keyBox)

            $progressBar = New-Object System.Windows.Forms.ProgressBar
            $progressBar.Location = New-Object System.Drawing.Point(10, 550)
            $progressBar.Size = New-Object System.Drawing.Size(760, 20)
            $progressBar.Visible = $false
            $form.Controls.Add($progressBar)

            $progressLabel = New-Object System.Windows.Forms.Label
            $progressLabel.Location = New-Object System.Drawing.Point(10, 575)
            $progressLabel.Size = New-Object System.Drawing.Size(760, 20)
            $progressLabel.Text = ""
            $form.Controls.Add($progressLabel)

            $btnExport = New-Object System.Windows.Forms.Button
            $btnExport.Text = "Export"
            $btnExport.Location = New-Object System.Drawing.Point(10, 605)
            $btnExport.Size = New-Object System.Drawing.Size(120, 30)
            $btnExport.Add_Click({
                    $OutputDir = $textBox.Text
                    $GenerateDocs = $docCheckBox.Checked
                    $ApiKey = $keyBox.Text

                    if (-not (Test-Path $OutputDir)) {
                        [System.Windows.Forms.MessageBox]::Show("Please provide a valid output directory.", "Error")
                        return
                    }
                    if ($GenerateDocs -and (-not $ApiKey)) {
                        [System.Windows.Forms.MessageBox]::Show("Please provide your OpenAI API key.", "Error")
                        return
                    }

                    $selectedPolicies = @()
                    foreach ($item in $checkedListBox.CheckedItems) {
                        $policy = $ConditionalAccessPolicies | Where-Object { $_.DisplayName -eq $item }
                        if ($policy) {
                            $selectedPolicies += $policy
                        }
                    }
                    $progressBar.Maximum = $selectedPolicies.Count
                    $progressBar.Value = 0
                    $progressBar.Visible = $true

                    $counter = 1
                    foreach ($Policy in $selectedPolicies) {
                        $progressLabel.Text = "Exporting $counter of $($selectedPolicies.Count) policies..."
                        [System.Windows.Forms.Application]::DoEvents()

                        # Enrich the policy JSON with display names and resolve references
                        $policy.Name
                        $ProcessedPolicies = Resolve-CAPolicyReferences -Policy $Policy
                        $PolicyName = $ProcessedPolicies.DisplayName -replace '[\\/:*?"<>|\[\]]', '-'
                        $json = $ProcessedPolicies | ConvertTo-Json -Depth 10
                        $json | Out-File "$OutputDir\$PolicyName.json" -Encoding utf8

                        if ($GenerateDocs) {
                            # Call OpenAI API to generate Markdown documentation from the JSON
                            $md = Request-OpenAIMarkdown -PolicyName $PolicyName -CAPolicyJSON $json -Key $ApiKey
                            if ($md) { $md | Out-File "$OutputDir\$PolicyName.md" -Encoding utf8 }
                        }

                        $progressBar.Value = $counter
                        $counter++
                        Start-Sleep -Milliseconds 1500
                    }
                    $progressLabel.Text = "Done"
                    [System.Windows.Forms.Application]::DoEvents()
                    [System.Windows.Forms.MessageBox]::Show("Export completed.", "Done")
                    
                })
            $form.Controls.Add($btnExport)

            $btnExit = New-Object System.Windows.Forms.Button
            $btnExit.Text = "Exit"
            $btnExit.Location = New-Object System.Drawing.Point(140, 605)
            $btnExit.Size = New-Object System.Drawing.Size(120, 30)
            $btnExit.Add_Click({ $form.Close() })
            $form.Controls.Add($btnExit)

            # Get all Conditional Access Policies and sort them.
            $ConditionalAccessPolicies = (Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies').value | Sort-Object DisplayName
            $ConditionalAccessPolicies | ForEach-Object {
                $null = $checkedListBox.Items.Add($_.DisplayName)
            }

            $form.ShowDialog() | Out-Null
            

        }
        
        else {
            Write-Output "Exporting Conditional Access policies with CLI..."

            # Get all Conditional Access Policies
            $ConditionalAccessPolicies = (Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies').value | ConvertTo-Json -Depth 10

            # Apply search patterns
            if ($PSBoundParameters.ContainsKey('CAPolicyPrefix')) {
                $ConditionalAccessPolicies = $ConditionalAccessPolicies | Where-Object { $_.DisplayName -like "$CAPolicyPrefix*" }
            }
            elseif ($PSBoundParameters.ContainsKey('CAPolicyPattern')) {
                $ConditionalAccessPolicies = $ConditionalAccessPolicies | Where-Object { $_.DisplayName -match $CAPolicyPattern }
            }
            else {
                $ConditionalAccessPolicies = $ConditionalAccessPolicies
            }

            #Process Policies
            $Result = foreach ($Policy in $ConditionalAccessPolicies) {
                Resolve-CAPolicyReferences -Policy $Policy
            }

            # SStore policy information in JSON file
            foreach ($Policy in $Result) {
                # Enrich the policy JSON with display names and resolve references
                $ProcessedPolicies = Resolve-CAPolicyReferences -Policy $Policy
                $PolicyName = $ProcessedPolicies.DisplayName -replace '[\\/:*?"<>|\[\]]', '-'
                $json = $ProcessedPolicies | ConvertTo-Json -Depth 10
                $json | Out-File "$OutputDir\$PolicyName.json" -Encoding utf8
                            
                Write-Host "Export of the Conditional Access Policy: $($Policy.DisplayName)" -ForegroundColor Green

                # When markdown documentation with OpenAI API is specified
                if ($OpenAIKey) {
                    
                    # Call OpenAI API to generate Markdown documentation from the JSON
                    $md = Request-OpenAIMarkdown -PolicyName $PolicyName -CAPolicyJSON $json -Key $ApiKey
                    if ($md) { $md | Out-File "$OutputDir\$PolicyName.md" -Encoding utf8 }
                    
                }
                Start-Sleep -Milliseconds 1500
            }
        }
    }
    catch {
        # Exception handling
        Write-Error "An error is occured: $($_.Exception.Message)"
    }
}

end {
    if (-not $GUI) {
        Disconnect-MgGraph
        Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Cyan
    }
}
