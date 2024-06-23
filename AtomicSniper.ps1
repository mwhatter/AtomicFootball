Add-Type -AssemblyName PresentationFramework

# Import invoke-atomicredteam module, launch AtomicSetup if not found
try {
    Import-Module invoke-atomicredteam -ErrorAction Stop
    Write-Host "invoke-atomicredteam module successfully imported."
}
catch {
    Write-Host "invoke-atomicredteam module not found. Running AtomicSetup.ps1..."
    .\AtomicSetup.ps1
}

# Function to show a popup message
function Show-PopupMessage {
    param (
        [string]$message,
        [string]$title = "Notification"
    )
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    [System.Windows.Forms.MessageBox]::Show($message, $title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
}

# Function to search for the AtomicRedTeam directory in the root of available drives
function Find-AtomicRedTeamDirectory {
    $drives = Get-PSDrive -PSProvider FileSystem
    foreach ($drive in $drives) {
        $path = Join-Path -Path $drive.Root -ChildPath "AtomicRedTeam"
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

# Function to check if Atomics are ready
function Check-AtomicsReady {
    param (
        [string]$atomicRedTeamPath
    )
    $createRemoteThreadPath = Join-Path -Path $atomicRedTeamPath -ChildPath "atomics\T1055\bin\x64\CreateRemoteThread.exe"
    if (-not (Test-Path $createRemoteThreadPath)) {
        Show-PopupMessage -message "Atomics are not ready. Reinstall to resume testing."
        .\AtomicSetup.ps1
        return $false
    }
    write-host "Atomics Armed and Ready"
    return $true
}

# Function to load CSV content and update deduplicated content
function Load_CsvContent {
    param (
        [string]$csvPath
    )
    if (-not (Test-Path $csvPath)) {
        Write-Host "CSV file not found at $csvPath."
        exit
    }

    # Load the CSV content into memory
    $csvContent = Import-Csv -Path $csvPath

    # Deduplicate by Test GUID and combine Tactics
    $global:deduplicatedContent = $csvContent | Group-Object -Property "Test GUID" | ForEach-Object {
        $group = $_.Group
        [PSCustomObject]@{
            "Tactic"        = ($group | Select-Object -ExpandProperty "Tactic" | Sort-Object -Unique) -join ", "
            "Technique #"   = $group[0]."Technique #"
            "Technique Name"= $group[0]."Technique Name"
            "Test #"        = $group[0]."Test #"
            "Test Name"     = $group[0]."Test Name"
            "Test GUID"     = $group[0]."Test GUID"
            "Executor Name" = $group[0]."Executor Name"
        }
    }

    # Extract unique techniques from the deduplicated content
    $global:techniques = $global:deduplicatedContent | Select-Object -ExpandProperty "Technique #" | Sort-Object -Unique
}

# Initialize the main log file
$logPath = ".\TestResults.log"
if (-not (Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType File
} else {
    Clear-Content -Path $logPath
}

# Function to log messages
function Log_Message {
    param (
        [string]$message
    )
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $logEntry = "$timestamp - $message"
    Add-Content -Path $logPath -Value $logEntry
    $global:resultsTextBox.AppendText("$logEntry`r`n")
}

# Function to start ProcMon
function Start-ProcMon {
    param (
        [string]$procmonPath
    )
    # Check if ProcMon is already running and terminate it
    $procMonProcess = Get-Process -Name "Procmon64" -ErrorAction SilentlyContinue
    if ($procMonProcess) {
        Terminate_ProcMon -procmonPath $procmonPath
    }

    Start-Process -FilePath $procmonPath -ArgumentList "/Minimized"
}

# Function to terminate ProcMon gracefully
function Terminate_ProcMon {
    param (
        [string]$procmonPath
    )
    Start-Process -FilePath $procmonPath -ArgumentList "/Terminate"
}

# Function to get the processes started by a specific command
function Get-ProcessesStartedByCommand {
    param (
        [string]$command
    )

    $beforeProcesses = Get-Process
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", $command

    Start-Sleep -Seconds 5 

    $afterProcesses = Get-Process
    $newProcesses = Compare-Object -ReferenceObject $beforeProcesses -DifferenceObject $afterProcesses -Property Id | Where-Object { $_.SideIndicator -eq "=>" } | Select-Object -ExpandProperty Id

    return $newProcesses
}

# Function to wait for all specified processes to exit
function Wait-ForProcessesToExit {
    param (
        [int[]]$processIds
    )

    while ($true) {
        $runningProcesses = Get-Process -Id $processIds -ErrorAction SilentlyContinue
        if ($runningProcesses.Count -eq 0) {
            break
        }
        Start-Sleep -Seconds 5
    }
}

# Function to run tests for techniques and tests
function Run_TechniqueTests {
    param (
        [string]$techniqueId,
        [string]$testNumber,
        [string]$procmonPath,
        [bool]$promptForInputArgs
    )

    $logCsvPath = ".\log.csv"

    Start-ProcMon -procmonPath $procmonPath

    $command = "Invoke-AtomicTest $techniqueId -ExecutionLogPath $logCsvPath"
    if ($promptForInputArgs) {
        $command += " -PromptForInputArgs"
    }
    if ($testNumber) {
        $command += " -TestNumbers $testNumber"
    }

    # Construct the command to run both prerequisites and the actual test in the same window
    $completeCommand = "$command -GetPrereqs; $command; Write-Host 'Procmon will run until this window is closed.'"

    # Log the command
    Log_Message "Executing command: $completeCommand"

    $processIds = Get-ProcessesStartedByCommand -command $completeCommand

    Wait-ForProcessesToExit -processIds $processIds

    Terminate_ProcMon -procmonPath $procmonPath
}

# Function to run cleanup for techniques and tests
function Run_Cleanup {
    param (
        [string]$techniqueId,
        [string]$testNumber
    )

    $command = "Invoke-AtomicTest $techniqueId -ExecutionLogPath '.\log.csv'"
    if ($testNumber) {
        $command += " -TestNumbers $testNumber"
    }
    $command += " -Cleanup"
    Start-Process powershell -ArgumentList "-NoExit -Command $command"
}

# Function to show technique details in a new PowerShell window
function Show-TechniqueDetails {
    param (
        [string]$techniqueId,
        [string]$testNumber
    )

    $command = "Invoke-AtomicTest $techniqueId -ExecutionLogPath '.\log.csv'"
    if ($testNumber) {
        $command += " -TestNumbers $testNumber"
    }
    $command += " -ShowDetails"
    Start-Process powershell -ArgumentList "-NoExit -Command $command"
}

# Function to create and show the main GUI
function Show-MainGUI {
    Add-Type -AssemblyName PresentationFramework

    $window = New-Object System.Windows.Window
    $window.Title = "AtomicSniper"
    $window.Width = 800
    $window.Height = 600
    $window.WindowStartupLocation = 'CenterScreen'

    $dockPanel = New-Object System.Windows.Controls.DockPanel
    $window.Content = $dockPanel
    $dockPanel.Background = 'Black'

    # CSV file path input and Browse button
    $csvPanel = New-Object System.Windows.Controls.StackPanel
    $csvPanel.Orientation = 'Horizontal'
    $csvPanel.HorizontalAlignment = 'Center'
    $csvPanel.Margin = [System.Windows.Thickness]::new(10)
    $dockPanel.Children.Add($csvPanel)
    [System.Windows.Controls.DockPanel]::SetDock($csvPanel, 'Top')

    $csvTextBox = New-Object System.Windows.Controls.TextBox
    $csvTextBox.Width = 500
    $csvTextBox.Margin = [System.Windows.Thickness]::new(10)
    $csvTextBox.Foreground = 'SeaGreen'
    $csvTextBox.Background = 'Black'
    $csvTextBox.BorderBrush = 'SeaGreen'
    $csvTextBox.TextAlignment = 'Right'
    $csvTextBox.Text = $indexCsvPath
    $csvPanel.Children.Add($csvTextBox)

    $browseButton = New-Object System.Windows.Controls.Button
    $browseButton.Content = "Browse"
    $browseButton.Width = 80
    $browseButton.Height = 30
    $browseButton.Margin = [System.Windows.Thickness]::new(10)
    $browseButton.Background = 'SeaGreen'
    $browseButton.Foreground = 'Black'
    $browseButton.Add_Click({
        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
        $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $fileDialog.InitialDirectory = [System.IO.Path]::GetDirectoryName($csvTextBox.Text)
        $fileDialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
        $fileDialog.ShowDialog() | Out-Null
        $csvTextBox.Text = $fileDialog.FileName
    })
    $csvPanel.Children.Add($browseButton)

    $updateButton = New-Object System.Windows.Controls.Button
    $updateButton.Content = "Update Techniques"
    $updateButton.Width = 120
    $updateButton.Height = 30
    $updateButton.Margin = [System.Windows.Thickness]::new(10)
    $updateButton.Background = 'SeaGreen'
    $updateButton.Foreground = 'Black'
    $updateButton.Add_Click({
        $csvPath = $csvTextBox.Text
        if ($csvPath -ne "" -and (Test-Path $csvPath)) {
            try {
                Load_CsvContent -csvPath $csvPath
                $techniqueComboBox.Items.Clear()
                $techniqueComboBox.Items.Add("Select TechniqueID")
                $techniqueComboBox.SelectedIndex = 0
                ($global:techniques | Sort-Object) | ForEach-Object { $techniqueComboBox.Items.Add($_) }
                Log_Message "CSV loaded successfully: $csvPath"
            } catch {
                Log_Message "Failed to load CSV: $csvPath"
            }
        } else {
            Log_Message "Invalid or no CSV file specified."
        }
    })
    $csvPanel.Children.Add($updateButton)

    # Panel for ComboBoxes and Buttons
    $comboButtonPanel = New-Object System.Windows.Controls.StackPanel
    $comboButtonPanel.Orientation = 'Horizontal'
    $comboButtonPanel.HorizontalAlignment = 'Center'
    $comboButtonPanel.Margin = [System.Windows.Thickness]::new(10)
    $dockPanel.Children.Add($comboButtonPanel)
    [System.Windows.Controls.DockPanel]::SetDock($comboButtonPanel, 'Top')

    $techniqueComboBox = New-Object System.Windows.Controls.ComboBox
    $techniqueComboBox.Width = 130
    $techniqueComboBox.Margin = [System.Windows.Thickness]::new(10)
    $techniqueComboBox.Foreground = 'SeaGreen'
    $techniqueComboBox.Background = 'Black'
    $techniqueComboBox.BorderBrush = 'SeaGreen'
    $techniqueComboBox.Items.Add("Select TechniqueID")
    $techniqueComboBox.SelectedIndex = 0
    ($global:techniques | Sort-Object) | ForEach-Object { $techniqueComboBox.Items.Add($_) } # Sorted techniques
    $comboButtonPanel.Children.Add($techniqueComboBox)

    $testComboBox = New-Object System.Windows.Controls.ComboBox
    $testComboBox.Width = 130
    $testComboBox.Margin = [System.Windows.Thickness]::new(10)
    $testComboBox.Foreground = 'SeaGreen'
    $testComboBox.Background = 'Black'
    $testComboBox.BorderBrush = 'SeaGreen'
    $testComboBox.Items.Add("Select TestNumber")
    $testComboBox.SelectedIndex = 0
    $comboButtonPanel.Children.Add($testComboBox)

    $promptForInputArgsCheckbox = New-Object System.Windows.Controls.CheckBox
    $promptForInputArgsCheckbox.Content = "Prompt For Inputs"
    $promptForInputArgsCheckbox.Foreground = 'SeaGreen'
    $promptForInputArgsCheckbox.Margin = [System.Windows.Thickness]::new(10)
    $comboButtonPanel.Children.Add($promptForInputArgsCheckbox)

    $runButton = New-Object System.Windows.Controls.Button
    $runButton.Content = "Run"
    $runButton.Width = 100
    $runButton.Height = 30
    $runButton.Margin = [System.Windows.Thickness]::new(5)
    $runButton.Background = 'SeaGreen'
    $runButton.Foreground = 'Black'
    $runButton.Add_Click({
        $selectedTechnique = $techniqueComboBox.SelectedItem
        $selectedTest = $testComboBox.SelectedItem
        $promptForInputArgs = $promptForInputArgsCheckbox.IsChecked
        if ($selectedTechnique -ne "Select TechniqueID") {
            $procmonPath = ".\Procmon64.exe"  # Use the local path to Procmon
            $testNumber = if ($selectedTest -ne "Select TestNumber") { $selectedTest } else { $null }
            Run_TechniqueTests -techniqueId $selectedTechnique -testNumber $testNumber -procmonPath $procmonPath -promptForInputArgs $promptForInputArgs
        }
    })
    $comboButtonPanel.Children.Add($runButton)

    $cleanupButton = New-Object System.Windows.Controls.Button
    $cleanupButton.Content = "Cleanup"
    $cleanupButton.Width = 100
    $cleanupButton.Height = 30
    $cleanupButton.Margin = [System.Windows.Thickness]::new(5)
    $cleanupButton.Background = 'SeaGreen'
    $cleanupButton.Foreground = 'Black'
    $cleanupButton.Add_Click({
        $selectedTechnique = $techniqueComboBox.SelectedItem
        $selectedTest = $testComboBox.SelectedItem
        if ($selectedTechnique -ne "Select TechniqueID") {
            $testNumber = if ($selectedTest -ne "Select TestNumber") { $selectedTest } else { $null }
            Run_Cleanup -techniqueId $selectedTechnique -testNumber $testNumber
        }
    })
    $comboButtonPanel.Children.Add($cleanupButton)

    $detailsButton = New-Object System.Windows.Controls.Button
    $detailsButton.Content = "Show Details"
    $detailsButton.Width = 100
    $detailsButton.Height = 30
    $detailsButton.Margin = [System.Windows.Thickness]::new(5)
    $detailsButton.Background = 'SeaGreen'
    $detailsButton.Foreground = 'Black'
    $detailsButton.Add_Click({
        $selectedTechnique = $techniqueComboBox.SelectedItem
        $selectedTest = $testComboBox.SelectedItem
        if ($selectedTechnique -ne "Select TechniqueID") {
            $testNumber = if ($selectedTest -ne "Select TestNumber") { $selectedTest } else { $null }
            Show-TechniqueDetails -techniqueId $selectedTechnique -testNumber $testNumber
        }
    })
    $comboButtonPanel.Children.Add($detailsButton)

    # ScrollViewer for Results
    $scrollViewerResults = New-Object System.Windows.Controls.ScrollViewer
    $scrollViewerResults.VerticalScrollBarVisibility = 'Auto'
    $scrollViewerResults.HorizontalScrollBarVisibility = 'Auto'
    $dockPanel.Children.Add($scrollViewerResults)
    [System.Windows.Controls.DockPanel]::SetDock($scrollViewerResults, 'Bottom')

    $resultsTextBox = New-Object System.Windows.Controls.TextBox
    $resultsTextBox.Width = 750
    $resultsTextBox.HorizontalAlignment = 'Center'
    $resultsTextBox.VerticalAlignment = 'Top'
    $resultsTextBox.Margin = [System.Windows.Thickness]::new(10)
    $resultsTextBox.IsReadOnly = $true
    $resultsTextBox.Foreground = 'SeaGreen'
    $resultsTextBox.Background = 'Black'
    $resultsTextBox.TextWrapping = 'Wrap'
    $resultsTextBox.VerticalScrollBarVisibility = 'Auto'
    $resultsTextBox.HorizontalScrollBarVisibility = 'Auto'
    $resultsTextBox.Height = 400
    $scrollViewerResults.Content = $resultsTextBox

    $global:resultsTextBox = $resultsTextBox

    $techniqueComboBox.Add_SelectionChanged({
        $selectedTechnique = $techniqueComboBox.SelectedItem
        if ($selectedTechnique -ne "Select TechniqueID") {
            $testComboBox.Items.Clear()
            $testComboBox.Items.Add("Select TestNumber")
            $testComboBox.SelectedIndex = 0
            $techniqueDetails = $global:deduplicatedContent | Where-Object { $_."Technique #" -eq $selectedTechnique } | Sort-Object { [int]$_."Test #" }
            $details = ($techniqueDetails | ForEach-Object {
                "Tactic: $($_.Tactic)`nTechnique #: $($_.'Technique #')`nTechnique Name: $($_.'Technique Name')`nTest #: $($_.'Test #')`nTest Name: $($_.'Test Name')`nTest GUID: $($_.'Test GUID')`nExecutor Name: $($_.'Executor Name')`n"
            }) -join "`n"
            $global:resultsTextBox.Text = $details
            ($techniqueDetails | Select-Object -Unique -ExpandProperty 'Test #' | Sort-Object { [int]$_ }) | ForEach-Object { $testComboBox.Items.Add($_) } # Sorted test numbers as integers
        }
    })

    $testComboBox.Add_SelectionChanged({
        $selectedTechnique = $techniqueComboBox.SelectedItem
        $selectedTest = $testComboBox.SelectedItem
        if ($selectedTest -ne "Select TestNumber" -and $selectedTechnique -ne "Select TechniqueID") {
            $testDetails = $global:deduplicatedContent | Where-Object { $_."Technique #" -eq $selectedTechnique -and $_."Test #" -eq $selectedTest }
            $details = ($testDetails | ForEach-Object {
                "Tactic: $($_.Tactic)`nTechnique #: $($_.'Technique #')`nTechnique Name: $($_.'Technique Name')`nTest #: $($_.'Test #')`nTest Name: $($_.'Test Name')`nTest GUID: $($_.'Test GUID')`nExecutor Name: $($_.'Executor Name')`n"
            }) -join "`n"
            $global:resultsTextBox.Text = $details
        } elseif ($selectedTechnique -ne "Select TechniqueID" -and $selectedTest -eq "Select TestNumber") {
            $techniqueDetails = $global:deduplicatedContent | Where-Object { $_."Technique #" -eq $selectedTechnique } | Sort-Object { [int]$_."Test #" }
            $details = ($techniqueDetails | ForEach-Object {
                "Tactic: $($_.Tactic)`nTechnique #: $($_.'Technique #')`nTechnique Name: $($_.'Technique Name')`nTest #: $($_.'Test #')`nTest Name: $($_.'Test Name')`nTest GUID: $($_.'Test GUID')`nExecutor Name: $($_.'Executor Name')`n"
            }) -join "`n"
            $global:resultsTextBox.Text = $details
        }
    })

    $window.ShowDialog() | Out-Null
}

# Load initial CSV content
$atomicRedTeamPath = Find-AtomicRedTeamDirectory

if ($atomicRedTeamPath -and (Check-AtomicsReady -atomicRedTeamPath $atomicRedTeamPath)) {
    $indexCsvPath = Join-Path -Path $atomicRedTeamPath -ChildPath "atomics\Indexes\Indexes-CSV\index.csv"
    Load_CsvContent -csvPath $indexCsvPath

    # Show the main GUI
    Show-MainGUI
}
