# Import the required assemblies
Add-Type -AssemblyName PresentationFramework

# Create the main window
[void][System.Reflection.Assembly]::LoadWithPartialName("presentationcore")
[void][System.Reflection.Assembly]::LoadWithPartialName("presentationframework")

$window = New-Object Windows.Window
$window.Title = "AtomicFootball Setup"
$window.Width = 700
$window.Height = 820
$window.Background = [System.Windows.Media.Brushes]::Black
$window.Top = 1  

# Create a stack panel layout
$stackPanel = New-Object Windows.Controls.StackPanel
$stackPanel.Margin = "5"
$window.Content = $stackPanel

# Add labels, checkboxes, text boxes, and buttons
function Add-Label($stackPanel, $content, $columnSpan = 1) {
    $label = New-Object Windows.Controls.Label
    $label.Content = $content
    $label.Margin = "5"
    $label.Foreground = [System.Windows.Media.Brushes]::SeaGreen
    $label.Background = [System.Windows.Media.Brushes]::Black
    [void]$stackPanel.Children.Add($label)
    if ($columnSpan -gt 1) {
        [void][Windows.Controls.Grid]::SetColumnSpan($label, $columnSpan)
    }
}

function Add-CheckboxWithExplanation($stackPanel, $content, $explanation) {
    $grid = New-Object Windows.Controls.Grid
    $grid.Margin = "5"
    [void]$stackPanel.Children.Add($grid)

    # Define the columns
    $col1 = New-Object Windows.Controls.ColumnDefinition
    $col1.Width = "2*"  
    $col2 = New-Object Windows.Controls.ColumnDefinition
    $col2.Width = "9*" 
    $grid.ColumnDefinitions.Add($col1)
    $grid.ColumnDefinitions.Add($col2)

    $checkbox = New-Object Windows.Controls.CheckBox
    $checkbox.Content = $content
    $checkbox.Margin = "5"
    $checkbox.Foreground = [System.Windows.Media.Brushes]::SeaGreen
    [void]$grid.Children.Add($checkbox)
    [void][Windows.Controls.Grid]::SetColumn($checkbox, 0)

    $label = New-Object Windows.Controls.Label
    $label.Content = $explanation
    $label.Margin = "5"
    $label.Foreground = [System.Windows.Media.Brushes]::SeaGreen
    $label.Background = [System.Windows.Media.Brushes]::Black
    $label.MaxWidth = 550
    [void]$grid.Children.Add($label)
    [void][Windows.Controls.Grid]::SetColumn($label, 1)

    return $checkbox
}

function Add-TextBox($stackPanel, $defaultText) {
    $textbox = New-Object Windows.Controls.TextBox
    $textbox.Margin = "5"
    $textbox.Background = [System.Windows.Media.Brushes]::White
    $textbox.Foreground = [System.Windows.Media.Brushes]::Black
    $textbox.IsHitTestVisible = $true
    $textbox.Focusable = $true
    $textbox.CaretBrush = [System.Windows.Media.Brushes]::Black
    $textbox.Text = $defaultText
    [void]$stackPanel.Children.Add($textbox)
    return $textbox
}

function Add-TextBoxWithExplanation($stackPanel, $labelContent, $defaultText, $explanation) {
    $grid = New-Object Windows.Controls.Grid
    $grid.Margin = "5"
    [void]$stackPanel.Children.Add($grid)

    # Define the columns
    $col1 = New-Object Windows.Controls.ColumnDefinition
    $col1.Width = "1*"  # 1 part
    $col2 = New-Object Windows.Controls.ColumnDefinition
    $col2.Width = "3*"  # 3 parts
    $grid.ColumnDefinitions.Add($col1)
    $grid.ColumnDefinitions.Add($col2)

    $label = New-Object Windows.Controls.Label
    $label.Content = $labelContent
    $label.Margin = "5"
    $label.Foreground = [System.Windows.Media.Brushes]::SeaGreen
    $label.Background = [System.Windows.Media.Brushes]::Black
    [void]$grid.Children.Add($label)
    [void][Windows.Controls.Grid]::SetColumn($label, 0)

    $textbox = New-Object Windows.Controls.TextBox
    $textbox.Margin = "5"
    $textbox.Background = [System.Windows.Media.Brushes]::White
    $textbox.Foreground = [System.Windows.Media.Brushes]::Black
    $textbox.IsHitTestVisible = $true
    $textbox.Focusable = $true
    $textbox.CaretBrush = [System.Windows.Media.Brushes]::Black
    $textbox.Text = $defaultText
    [void]$grid.Children.Add($textbox)
    [void][Windows.Controls.Grid]::SetColumn($textbox, 0)

    $labelExplanation = New-Object Windows.Controls.Label
    $labelExplanation.Content = $explanation
    $labelExplanation.Margin = "5"
    $labelExplanation.Foreground = [System.Windows.Media.Brushes]::SeaGreen
    $labelExplanation.Background = [System.Windows.Media.Brushes]::Black
    $labelExplanation.MaxWidth = 550
    [void]$grid.Children.Add($labelExplanation)
    [void][Windows.Controls.Grid]::SetColumn($labelExplanation, 1)

    return $textbox
}

function Add-Button($stackPanel, $content) {
    $button = New-Object Windows.Controls.Button
    $button.Content = $content
    $button.Margin = "5"
    $button.Padding = "5"
    $button.Background = [System.Windows.Media.Brushes]::SeaGreen
    $button.Foreground = [System.Windows.Media.Brushes]::Black
    [void]$stackPanel.Children.Add($button)
    return $button
}

# Add initial explanation
$gridTopRow = New-Object Windows.Controls.Grid
$gridTopRow.Margin = "5"
$gridTopRow.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
$colHelp = New-Object Windows.Controls.ColumnDefinition
$colHelp.Width = "auto"
$gridTopRow.ColumnDefinitions.Add($colHelp)
[void]$stackPanel.Children.Add($gridTopRow)

$labelTopRow = New-Object Windows.Controls.Label
$labelTopRow.Content = "Setup AtomicFootball - This will build the AtomicFootball directory from the repo."
$labelTopRow.Margin = "5"
$labelTopRow.Foreground = [System.Windows.Media.Brushes]::SeaGreen
$labelTopRow.Background = [System.Windows.Media.Brushes]::Black
[void]$gridTopRow.Children.Add($labelTopRow)
[void][Windows.Controls.Grid]::SetColumn($labelTopRow, 0)

$btnHelp = New-Object Windows.Controls.Button
$btnHelp.Content = "Help"
$btnHelp.Margin = "5"
$btnHelp.Padding = "5"
$btnHelp.Width = 75
$btnHelp.Background = [System.Windows.Media.Brushes]::SeaGreen
$btnHelp.Foreground = [System.Windows.Media.Brushes]::Black
[void]$gridTopRow.Children.Add($btnHelp)
[void][Windows.Controls.Grid]::SetColumn($btnHelp, 1)

function Show-HelpWindow {
    $helpWindow = New-Object Windows.Window
    $helpWindow.Title = "AtomicFootball Setup Help"
    $helpWindow.Width = 600
    $helpWindow.Height = 600
    $helpWindow.Background = [System.Windows.Media.Brushes]::Black

    $scrollViewer = New-Object Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = "Auto"
    $scrollViewer.HorizontalScrollBarVisibility = "Disabled"
    $helpWindow.Content = $scrollViewer

    $helpStackPanel = New-Object Windows.Controls.StackPanel
    $helpStackPanel.Margin = "10"
    $scrollViewer.Content = $helpStackPanel

    function Add-HelpLabel($stackPanel, $content) {
        $label = New-Object Windows.Controls.TextBlock
        $label.Text = $content
        $label.Margin = "5"
        $label.Foreground = [System.Windows.Media.Brushes]::SeaGreen
        $label.Background = [System.Windows.Media.Brushes]::Black
        $label.TextWrapping = "Wrap"
        [void]$stackPanel.Children.Add($label)
    }

    $helpContent = @"
AtomicFootball Setup

The AtomicFootball Setup is a PowerShell GUI tool designed to simplify the setup and management of AtomicFootball and the Invoke-AtomicRedTeam framework. This tool provides a user-friendly interface for setting up directories, installing necessary modules, and configuring Procmon.

Prerequisites
- PowerShell 5.0 or later
- Administrative privileges to run certain commands
- Internet connection to download necessary tools and scripts

Instructions
Launching the Form
- Save the script file to your local machine with a .ps1 extension, e.g., AtomicSetup.ps1.
- Open PowerShell with administrative privileges.
- Change directory to the location of the saved script.
- Execute the script.

Using the Form
Setup AtomicFootball Directory
- Setup AtomicFootball: This will build the AtomicFootball directory from the repository.
- You can specify the directory location in the text box. The default location is C:\.
- Click the Setup AtomicFootball button to download and extract the AtomicFootball repository into the specified directory.

Install Invoke-AtomicRedTeam Framework
- Install AtomicRedTeam with Optional Arguments:
  - Include Atomics: Includes the Atomics folder containing test definitions. Necessary for running tests.
  - Force Install: Forces the installation even if the module is already installed. Use this to update or reinstall.
  - No Payloads: Installs the atomics directory with only the test definition YAML files and no payloads.
  - Install Path: Specify the installation path for Invoke-AtomicRedTeam. Default is C:\AtomicRedTeam.
  - Repo Owner: Specifies the GitHub repository owner. Default is redcanaryco.
  - Branch: Specifies the branch to use from the repository. Default is master.
- Click the Install Atomic Red Team button to install the Invoke-AtomicRedTeam framework with the specified options.
- Click the Install Powershell Modules button to install the required PowerShell modules (invoke-atomicredteam and powershell-yaml) from the PowerShell Gallery.
- Standalone Option. Install Atomics Only: Click the Install Atomics Only button to install only the Atomics folder.

Setup Procmon
- Setup Procmon: This will configure Procmon (Process Monitor) and direct the output to the AtomicFootball directory.
- Click the Setup Procmon button to download and extract Process Monitor, and create the EULA acceptance file to avoid prompts on the next run.

Reference
- Invoke-AtomicRedTeam Wiki: Click the hyperlink to open the Invoke-AtomicRedTeam Wiki in your default web browser for more information and detailed documentation.

Example Usage
- Launch the form by running .\AtomicSetup.ps1 as an administrator.
- Specify the desired directory for AtomicFootball or use the default.
- Click Setup AtomicFootball to download and set up the directory.
- Adjust any options for the Invoke-AtomicRedTeam installation.
- Click Install Powershell Modules to install the required PowerShell modules.
- Click Install Atomic Red Team to install the framework.
- Click Setup Procmon to configure Process Monitor.

Support
- For support and further information, refer to the Invoke-AtomicRedTeam Wiki.
"@

    Add-HelpLabel $helpStackPanel $helpContent
    $helpWindow.ShowDialog() | Out-Null
}

$btnHelp.Add_Click({ Show-HelpWindow })

# TextBox for specifying the AtomicFootball directory location
Add-Label $stackPanel "Directory Location" 2
$txtAtomicFootballDir = Add-TextBox $stackPanel "C:\"

# Button to setup AtomicFootball
$btnSetupAtomicFootballRepo = Add-Button $stackPanel "Setup AtomicFootball"

# Add components for installing Invoke-AtomicRedTeam
Add-Label $stackPanel "Install AtomicRedTeam with Optional Arguments." 2

$chkGetAtomics = Add-CheckboxWithExplanation $stackPanel "Include Atomics" "Includes the Atomics folder containing test definitions. Necessary for running tests."
$chkForce = Add-CheckboxWithExplanation $stackPanel "Force Install" "Forces the installation even if the module is already installed. Use this to update or reinstall."
$chkNoPayloads = Add-CheckboxWithExplanation $stackPanel "No Payloads" "Installs the atomics directory with only the test definition YAML files and no payloads."

Add-Label $stackPanel "Install Path" 2
$txtInstallPath = Add-TextBox $stackPanel "C:\AtomicRedTeam"

Add-Label $stackPanel "Repo Owner" 2
$txtRepoOwner = Add-TextBoxWithExplanation $stackPanel "Repo Owner" "redcanaryco" "Specifies the GitHub repository owner. Default is 'redcanaryco'."

Add-Label $stackPanel "Branch" 2
$txtBranch = Add-TextBoxWithExplanation $stackPanel "Branch" "master" "Specifies the branch to use from the repository. Default is 'master'."

$btnInstallAtomicRedTeam = Add-Button $stackPanel "Install Atomic Red Team"
$btnInstallModule = Add-Button $stackPanel "Install Powershell Modules"
$btnInstallAtomics = Add-Button $stackPanel "Install Atomics Only"

# Add reference hyperlink
$hyperlinkText = New-Object Windows.Documents.Run
$hyperlinkText.Text = "Invoke-AtomicRedTeam Wiki"
$hyperlink = New-Object Windows.Documents.Hyperlink
$hyperlink.NavigateUri = [Uri] "https://github.com/redcanaryco/invoke-atomicredteam/wiki/"
$hyperlink.Inlines.Add($hyperlinkText)
$hyperlink.Foreground = [System.Windows.Media.Brushes]::SeaGreen

$txtBlockHyperlink = New-Object Windows.Controls.TextBlock
$txtBlockHyperlink.Inlines.Add($hyperlink)
$txtBlockHyperlink.Margin = "5"
[void]$stackPanel.Children.Add($txtBlockHyperlink)

# Add click event handler to open hyperlink in default web browser
$hyperlink.Add_Click({
    Start-Process $hyperlink.NavigateUri.AbsoluteUri
})

# Add components for setting up Procmon
Add-Label $stackPanel "Setup Procmon - Output will be directed to the AtomicFootball directory." 2
$btnSetupProcmon = Add-Button $stackPanel "Setup Procmon"

# Add click event handlers
$btnSetupAtomicFootballRepo.Add_Click({
    function Setup-AtomicFootballRepo {
        $atomicFootballDir = $txtAtomicFootballDir.Text
        $atomicFootballRepoName = "AtomicFootball"
        $finalAtomicFootballDir = if ($atomicFootballDir -match "$atomicFootballRepoName$") {
            $atomicFootballDir
        } else {
            Join-Path -Path $atomicFootballDir -ChildPath $atomicFootballRepoName
        }

        if (-not (Test-Path -Path $finalAtomicFootballDir)) {
            New-Item -ItemType Directory -Path $finalAtomicFootballDir -Force
        }

        $atomicFootballZipUrl = "https://github.com/mwhatter/AtomicFootball/archive/refs/heads/main.zip"
        $atomicFootballZipPath = Join-Path -Path $finalAtomicFootballDir -ChildPath "AtomicFootball.zip"
        $atomicFootballExtractedPath = Join-Path -Path $finalAtomicFootballDir -ChildPath "AtomicFootball-main"

        # Download the AtomicFootball repository
        Invoke-WebRequest -Uri $atomicFootballZipUrl -OutFile $atomicFootballZipPath

        # Extract the AtomicFootball repository
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($atomicFootballZipPath, $finalAtomicFootballDir)

        # Move the extracted files to the final directory if needed
        $extractedDir = Join-Path -Path $finalAtomicFootballDir -ChildPath "AtomicFootball-main"
        if (Test-Path -Path $extractedDir) {
            Move-Item -Path (Join-Path -Path $finalAtomicFootballDir -ChildPath "AtomicFootball-main\*") -Destination $finalAtomicFootballDir -Force
            Remove-Item -Path $extractedDir -Force -Recurse
        }

        # Remove the downloaded ZIP file
        Remove-Item -Path $atomicFootballZipPath -Force
    }
    Setup-AtomicFootballRepo
    .\ExclusionHelper.ps1
})

$btnInstallModule.Add_Click({
    Install-Module -Name invoke-atomicredteam,powershell-yaml
})

$btnInstallAtomicRedTeam.Add_Click({
    $flags = ""
    if ($chkGetAtomics.IsChecked) {
        $flags += " -getAtomics"
    }
    if ($chkForce.IsChecked) {
        $flags += " -Force"
    }
    if ($chkNoPayloads.IsChecked) {
        $flags += " -noPayloads"
    }
    if ($txtInstallPath.Text -ne "") {
        $flags += " -InstallPath `"$($txtInstallPath.Text)`""
    }
    if ($txtRepoOwner.Text -ne "") {
        $flags += " -RepoOwner `"$($txtRepoOwner.Text)`""
    }
    if ($txtBranch.Text -ne "") {
        $flags += " -Branch `"$($txtBranch.Text)`""
    }

    
    IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
    Invoke-Expression "Install-AtomicRedTeam $flags"
})

$btnInstallAtomics.Add_Click({
    IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicsfolder.ps1' -UseBasicParsing)
    Install-AtomicsFolder
})

$btnSetupProcmon.Add_Click({
    function Setup-Procmon {
        # Search for the AtomicFootball directory, preferring C: drive
        $drives = Get-PSDrive -PSProvider FileSystem
        $preferredDrive = $drives | Where-Object { $_.Name -eq 'C' }
        $otherDrives = $drives | Where-Object { $_.Name -ne 'C' }

        $dirsToSearch = @($preferredDrive) + $otherDrives
        $atomicFootballDir = $null

        foreach ($drive in $dirsToSearch) {
            $searchDir = Get-ChildItem -Path "$($drive.Root)" -Filter 'AtomicFootball' -Recurse -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($searchDir) {
                $atomicFootballDir = $searchDir.FullName
                break
            }
        }

        if (-not $atomicFootballDir) {
            $atomicFootballDir = $txtAtomicFootballDir.Text
        }

        $procmonZipUrl = "https://download.sysinternals.com/files/ProcessMonitor.zip"
        $procmonZipPath = Join-Path -Path $atomicFootballDir -ChildPath "ProcessMonitor.zip"

        # Download and extract Process Monitor into the AtomicFootball directory
        Invoke-WebRequest -Uri $procmonZipUrl -OutFile $procmonZipPath
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($procmonZipPath, $atomicFootballDir)
        Remove-Item -Path $procmonZipPath -Force

        $procmonPath = Join-Path -Path $atomicFootballDir -ChildPath "Procmon64.exe"

        # Start Procmon
        if (Test-Path $procmonPath) {
            Start-Process -FilePath $procmonPath
        } else {
            [System.Windows.MessageBox]::Show("Procmon executable not found. Please check the setup.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }
    Setup-Procmon
})

# Show the window
$window.ShowDialog() | Out-Null
