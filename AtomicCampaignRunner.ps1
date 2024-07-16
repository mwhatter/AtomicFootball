# Import invoke-atomicredteam module, launch AtomicSetup if not found
try {
    Import-Module invoke-atomicredteam -ErrorAction Stop
    Write-Host "invoke-atomicredteam module successfully imported."
}
catch {
    Write-Host "invoke-atomicredteam module not found. Running AtomicSetup.ps1..."
    .\AtomicSetup.ps1
}

Add-Type -AssemblyName PresentationFramework

# Function to show a popup message
function Show-PopupMessage {
    param (
        [string]$message,
        [string]$title = "Notification"
    )
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    [System.Windows.Forms.MessageBox]::Show($message, $title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
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

# Define global variables for persistence and progress tracking
$global:persistenceFilePath = ".\CampaignProgress.json"
$global:logFilePath = ".\CampaignLog.txt"
$global:procmonPath = ".\Procmon64.exe"
$global:taskName = "ResumeCampaign"
$global:taskDescription = "Resumes the campaign on logon"
$global:taskScriptPath = "$PSScriptRoot\$(Split-Path -Leaf $MyInvocation.MyCommand.Path)"
$global:csvPath = ".\AtomicCampaign.csv"  # Default CSV path

# Function to log messages
function Log-Message {
    param (
        [string]$message,
        [string]$type = "INFO"
    )
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $logEntry = "$timestamp [$type] - $message"
    try {
        Add-Content -Path $global:logFilePath -Value $logEntry
    } catch {
        Write-Host "Error logging to file: $_"
    }
    Write-Host $logEntry
}

# Function to start ProcMon
function Start-ProcMon {
    param (
        [string]$procmonPath
    )
    Log-Message "Starting ProcMon"
    try {
        # Check if ProcMon is already running and terminate it
        $procMonProcess = Get-Process -Name "Procmon64" -ErrorAction SilentlyContinue
        if ($procMonProcess) {
            Stop-Process -Name "Procmon64" -Force
        }
        Start-Process -FilePath $procmonPath -ArgumentList "/Minimized"
        Log-Message "ProcMon started successfully"
    } catch {
        Log-Message "Error starting ProcMon: $_" "ERROR"
    }
}

# Function to terminate ProcMon gracefully
function Terminate-ProcMon {
    param (
        [string]$procmonPath
    )
    Log-Message "Terminating ProcMon"
    try {
        Start-Process -FilePath $procmonPath -ArgumentList "/Terminate"
        Log-Message "ProcMon terminated successfully"
    } catch {
        Log-Message "Error terminating ProcMon: $_" "ERROR"
    }
}

# Function to load CSV content
function Load-CsvContent {
    param (
        [string]$csvPath
    )
    Log-Message "Loading CSV content from $csvPath"
    try {
        if (-not (Test-Path $csvPath)) {
            Log-Message "CSV file not found at $csvPath" "ERROR"
            exit
        }

        # Load the CSV content into memory
        $csvContent = Import-Csv -Path $csvPath
        Log-Message "CSV content loaded: $(ConvertTo-Json -InputObject $csvContent -Compress)"

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
        Log-Message "Deduplicated CSV content: $(ConvertTo-Json -InputObject $global:deduplicatedContent -Compress)"
        Log-Message "CSV content loaded and processed successfully"
    } catch {
        Log-Message "Error loading CSV content: $_" "ERROR"
    }
}

# Function to save campaign progress
function Save-Progress {
    param (
        [int]$currentTestIndex
    )
    Log-Message "Saving progress at test index $currentTestIndex"
    try {
        $progressData = @{
            CurrentTestIndex = $currentTestIndex
            CsvPath = $global:csvPath
        }
        $progressData | ConvertTo-Json | Out-File -FilePath $global:persistenceFilePath
        Log-Message "Progress saved successfully: $(ConvertTo-Json -InputObject $progressData -Compress)"
    } catch {
        Log-Message "Error saving progress: $_" "ERROR"
    }
}

# Function to load campaign progress
function Load-Progress {
    Log-Message "Loading campaign progress"
    try {
        if (Test-Path $global:persistenceFilePath) {
            $progressData = Get-Content -Path $global:persistenceFilePath | ConvertFrom-Json
            $global:csvPath = $progressData.CsvPath
            Log-Message "Campaign progress loaded: $(ConvertTo-Json -InputObject $progressData -Compress)"
            return $progressData.CurrentTestIndex
        }
        Log-Message "No progress file found, starting from the beginning"
        return 0
    } catch {
        Log-Message "Error loading campaign progress: $_" "ERROR"
        return 0
    }
}

# Function to run tests for techniques and tests
function Run-TechniqueTests {
    param (
        [string]$techniqueId,
        [string]$testNumber
    )

    $logCsvPath = ".\log.csv"
    Log-Message "Entered Run-TechniqueTests with TechniqueID=$techniqueId and TestNumber=$testNumber"

    $command = "Invoke-AtomicTest $techniqueId -ExecutionLogPath $logCsvPath -TestNumbers $testNumber -GetPrereqs; Invoke-AtomicTest $techniqueId -ExecutionLogPath $logCsvPath -TestNumbers $testNumber; Invoke-AtomicTest $techniqueId -ExecutionLogPath $logCsvPath -TestNumbers $testNumber -Cleanup"

    # Log the command
    Log-Message "Executing command: $command"

    try {
        Invoke-Expression $command | Tee-Object -FilePath $global:logFilePath -Append
        Log-Message "Command executed successfully"
    } catch {
        Log-Message "Error executing command: $_" "ERROR"
    }

    Log-Message "Exiting Run-TechniqueTests"
}

# Function to run the campaign
function Run-Campaign {
    $currentTestIndex = Load-Progress

    Start-ProcMon -procmonPath $global:procmonPath
    Start-Sleep -Seconds 5

    for ($i = $currentTestIndex; $i -lt $global:deduplicatedContent.Count; $i++) {
        $test = $global:deduplicatedContent[$i]
        Log-Message "Running test index $i with TechniqueID=$($test."Technique #") and TestNumber=$($test."Test #")"
        Run-TechniqueTests -techniqueId $test."Technique #" -testNumber $test."Test #"
        Save-Progress -currentTestIndex ($i + 1)
    }

    Start-Sleep -Seconds 3
    Terminate-ProcMon -procmonPath $global:procmonPath

    # Clear progress file after completion
    Log-Message "Campaign completed successfully"
    Remove-Item -Path $global:persistenceFilePath -ErrorAction SilentlyContinue

    # Disable the scheduled task after campaign completion
    try {
        Disable-ScheduledTask -TaskName $global:taskName
        Log-Message "Scheduled task disabled successfully"
    } catch {
        Log-Message "Error disabling scheduled task: $_" "ERROR"
    }
}

# Function to create or enable a scheduled task
function Create-Or-Enable-ScheduledTask {
    Log-Message "Creating or enabling scheduled task"
    try {
        $task = Get-ScheduledTask -TaskName $global:taskName -ErrorAction SilentlyContinue
        if ($null -eq $task) {
            $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-NoProfile -WindowStyle Hidden -File `"$global:taskScriptPath`""
            $trigger = New-ScheduledTaskTrigger -AtLogOn
            $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
            Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName $global:taskName -Description $global:taskDescription
            Log-Message "Scheduled task created successfully"
        } else {
            Enable-ScheduledTask -TaskName $global:taskName
            Log-Message "Scheduled task enabled successfully"
        }
    } catch {
        Log-Message "Error creating or enabling scheduled task: $_" "ERROR"
    }
}

# Function to run cleanup commands for each test
function Run-Cleanup {
    Log-Message "Running cleanup for all tests"

    for ($i = 0; $i -lt $global:deduplicatedContent.Count; $i++) {
        $test = $global:deduplicatedContent[$i]
        Log-Message "Running cleanup for TechniqueID=$($test."Technique #") and TestNumber=$($test."Test #")"

        $command = "Invoke-AtomicTest $($test."Technique #") -TestNumbers $($test."Test #") -Cleanup"

        try {
            Invoke-Expression $command | Tee-Object -FilePath $global:logFilePath -Append
            Log-Message "Cleanup command executed successfully for TechniqueID=$($test."Technique #") and TestNumber=$($test."Test #")"
        } catch {
            Log-Message "Error executing cleanup command for TechniqueID=$($test."Technique #") and TestNumber=$($test."Test #"): $_" "ERROR"
        }
    }

    Log-Message "Cleanup completed for all tests"
}

# Function to create and show the GUI
function Show-GUI {
    $window = New-Object System.Windows.Window
    $window.Title = "Atomic Campaign Runner"
    $window.Width = 700  
    $window.Height = 150
    $window.WindowStartupLocation = 'CenterScreen'
    $window.Foreground = 'SeaGreen'
    $window.Background = 'Black'

    $stackPanel = New-Object System.Windows.Controls.StackPanel
    $stackPanel.Orientation = 'Horizontal'
    $stackPanel.HorizontalAlignment = 'Center'
    $stackPanel.VerticalAlignment = 'Center'
    $stackPanel.Margin = [System.Windows.Thickness]::new(10)
    $window.Content = $stackPanel

    $csvTextBox = New-Object System.Windows.Controls.TextBox
    $csvTextBox.Width = 300
    $csvTextBox.Margin = [System.Windows.Thickness]::new(10)
    $csvTextBox.Text = $global:csvPath
    $csvTextBox.VerticalContentAlignment = 'Center'
    $csvTextBox.Foreground = 'SeaGreen'
    $csvTextBox.BorderBrush = 'SeaGreen'
    $csvTextBox.TextAlignment = 'Right'
    $stackPanel.Children.Add($csvTextBox)

    $browseButton = New-Object System.Windows.Controls.Button
    $browseButton.Content = "Browse"
    $browseButton.Width = 120
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
        $global:csvPath = $fileDialog.FileName
        Log-Message "CSV file selected: $($fileDialog.FileName)"
    })
    $stackPanel.Children.Add($browseButton)

    $runButton = New-Object System.Windows.Controls.Button
    $runButton.Content = "Run Campaign"
    $runButton.Width = 100
    $runButton.Height = 30
    $runButton.Margin = [System.Windows.Thickness]::new(10)
    $runButton.Background = 'SeaGreen'
    $runButton.Foreground = 'Black'
    $runButton.Add_Click({
        if ($csvTextBox.Text -ne "") {
            $global:csvPath = $csvTextBox.Text
            Create-Or-Enable-ScheduledTask
            Load-CsvContent -csvPath $global:csvPath
            Log-Message "Running campaign"
            Run-Campaign
        } else {
            Log-Message "No CSV file selected" "ERROR"
            [System.Windows.MessageBox]::Show("Please select a CSV file before running the campaign.")
        }
    })
    $stackPanel.Children.Add($runButton)

    # Add a button to run cleanup
    $cleanupButton = New-Object System.Windows.Controls.Button
    $cleanupButton.Content = "Just Cleanup"
    $cleanupButton.Width = 100
    $cleanupButton.Height = 30
    $cleanupButton.Margin = [System.Windows.Thickness]::new(10)
    $cleanupButton.Background = 'SeaGreen'
    $cleanupButton.Foreground = 'Black'
    $cleanupButton.Add_Click({
        if ($csvTextBox.Text -ne "") {
            $global:csvPath = $csvTextBox.Text
            Load-CsvContent -csvPath $global:csvPath
            Log-Message "Running cleanup"
            Run-Cleanup
        } else {
            Log-Message "No CSV file selected" "ERROR"
            [System.Windows.MessageBox]::Show("Please select a CSV file before running the cleanup.")
        }
    })
    $stackPanel.Children.Add($cleanupButton)

    $window.ShowDialog() | Out-Null
}

# Load initial CSV content
$atomicRedTeamPath = Find-AtomicRedTeamDirectory

if (Check-AtomicsReady -atomicRedTeamPath $atomicRedTeamPath) {
    # Show the GUI
    Show-GUI
}
