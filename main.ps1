<#
.SYNOPSIS
    Launches a main graphical user interface (GUI) to run Conditional Access import, export, rename, document, and delete scripts.

.DESCRIPTION
    This script creates a Windows Forms-based GUI that serves as a launcher for five scripts:
    - Import-CAPolicies.ps1 (located in .\Import)
    - Get-CAPolicies.ps1 (located in .\Export)
    - Rename-CAPolicies.ps1 (located in .\Rename)
    - Delete-CAPolicies.ps1 (located in .\Delete)
    - Document-CAPolicies.ps1 (located in .\Document)

    The GUI provides:
    - A progress label for visual context
    - Five buttons to execute the respective scripts in GUI mode
    - A persistent form that remains open until explicitly closed by the user

    All sub-scripts are called with the parameter `-GUI`, and no new PowerShell window is opened.
    Error handling is included to notify the user via message boxes if a script is missing or fails to execute.

.NOTES
    Author: Patrick Seltmann  
   Version: 0.1.0 
   Created: 2025-05-03  
   Prerequisites: 
    - Microsoft.Graph PowerShell SDK
    - PowerShell V7

.EXAMPLE
    PS C:\> .\main.ps1
#>

begin {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
}

process {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "CAxPorter Utility | main menu"
    $form.Size = New-Object System.Drawing.Size(420, 410)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false

    $headerLabel = New-Object System.Windows.Forms.Label
    $headerLabel.Text = "CAxPorter Utility"
    $headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $headerLabel.Location = New-Object System.Drawing.Point(20, 10)
    $headerLabel.Size = New-Object System.Drawing.Size(380, 30)
    $form.Controls.Add($headerLabel)

    $progressLabel = New-Object System.Windows.Forms.Label
    $progressLabel.Text = "Choose an option:"
    $progressLabel.Location = New-Object System.Drawing.Point(20, 50)
    $progressLabel.Size = New-Object System.Drawing.Size(350, 20)
    $form.Controls.Add($progressLabel)

    $importButton = New-Object System.Windows.Forms.Button
    $importButton.Text = "Import CA policies"
    $importButton.Location = New-Object System.Drawing.Point(20, 90)
    $importButton.Size = New-Object System.Drawing.Size(160, 40)
    $importButton.Add_Click({
            $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "scripts\import\import-CAPolicies.ps1"
            if (Test-Path $scriptPath) {
                & $scriptPath -GUI
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("Import script not found!", "Error")
            }
        })
    $form.Controls.Add($importButton)

    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Text = "Export CA policies"
    $btnExport.Location = New-Object System.Drawing.Point(210, 90)
    $btnExport.Size = New-Object System.Drawing.Size(160, 40)
    $btnExport.Add_Click({
            $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "scripts\export\export-CAPolicies.ps1"
            if (Test-Path $scriptPath) {
                & $scriptPath -GUI
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("Export script not found!", "Error")
            }
        })
    $form.Controls.Add($btnExport)

    $btnRename = New-Object System.Windows.Forms.Button
    $btnRename.Text = "Rename CA policies"
    $btnRename.Location = New-Object System.Drawing.Point(20, 150)
    $btnRename.Size = New-Object System.Drawing.Size(160, 40)
    $btnRename.Add_Click({
            $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "scripts\rename\rename-CAPolicies.ps1"
            if (Test-Path $scriptPath) {
                & $scriptPath -GUI
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("Rename script not found!", "Error")
            }
        })
    $form.Controls.Add($btnRename)

    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "Delete CA policies"
    $btnDelete.Location = New-Object System.Drawing.Point(210, 150)
    $btnDelete.Size = New-Object System.Drawing.Size(160, 40)
    $btnDelete.Add_Click({
            $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "scripts\delete\Delete-CAPolicies.ps1"
            if (Test-Path $scriptPath) {
                & $scriptPath -GUI
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("Delete script not found!", "Error")
            }
        })
    $form.Controls.Add($btnDelete)

    $btnDocument = New-Object System.Windows.Forms.Button
    $btnDocument.Text = "Document CA policies via OpenAI"
    $btnDocument.Location = New-Object System.Drawing.Point(20, 210)
    $btnDocument.Size = New-Object System.Drawing.Size(350, 30)
    $btnDocument.Add_Click({
            $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "scripts\document\document-CAPolicies.ps1"
            if (Test-Path $scriptPath) {
                & $scriptPath -GUI
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("Document script not found!", "Error")
            }
        })
    $form.Controls.Add($btnDocument)

    $exitButton = New-Object System.Windows.Forms.Button
    $exitButton.Text = "Exit"
    $exitButton.Location = New-Object System.Drawing.Point(20, 260)
    $exitButton.Size = New-Object System.Drawing.Size(350, 30)
    $exitButton.Add_Click({ $form.Close() })
    $form.Controls.Add($exitButton)

    $form.ShowDialog()
}

end {
    
    If (Get-MgContext) {
        Disconnect-MgGraph
        Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Cyan
    }
}
