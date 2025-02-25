# Define URLs
$dockerInstallerUrl = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
$installerPath = "$env:TEMP\DockerDesktopInstaller.exe"

# Function to check if WSL2 is installed
function Check-WSL2 {
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux"
    $vmPlatform = Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform"
    
    if ($wslFeature.State -ne "Enabled" -or $vmPlatform.State -ne "Enabled") {
        return $false
    }
    
    # Check if the default WSL version is 2
    $wslVersion = wsl --list --verbose 2>$null | Select-String ".* 2$"
    if ($wslVersion) {
        return $true
    }
    return $false
}

# Function to enable WSL2
function Enable-WSL2 {
    Write-Host "WSL2 is not installed. Installing now..."
    
    # Enable required features
    Write-Host "Enabling WSL and Virtual Machine Platform..."
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -All
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -All

    # Download and install the WSL2 kernel update
    Write-Host "Downloading WSL2 kernel update..."
    $wslUpdateUrl = "https://aka.ms/wsl2kernel"
    $wslUpdatePath = "$env:TEMP\wsl_update.msi"
    Invoke-WebRequest -Uri $wslUpdateUrl -OutFile $wslUpdatePath
    Start-Process -FilePath $wslUpdatePath -Wait

    # Set default WSL version to 2
    Write-Host "Setting WSL2 as default version..."
    wsl --set-default-version 2

    Write-Host "WSL2 installation complete. A system restart may be required."
}

# Check and enable WSL2 if necessary
if (-not (Check-WSL2)) {
    Enable-WSL2
}

# Download Docker Desktop Installer
Write-Host "Downloading Docker Desktop..."
Invoke-WebRequest -Uri $dockerInstallerUrl -OutFile $installerPath

# Install Docker Desktop silently
Write-Host "Installing Docker Desktop..."
Start-Process -FilePath $installerPath -ArgumentList "install", "--quiet" -Wait

# Ensure Docker starts on login
Write-Host "Configuring Docker to start on login..."
Start-Process -FilePath "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait for Docker to fully start
Write-Host "Waiting for Docker to start..."
Start-Sleep -Seconds 30

# Enable WSL2 support if available
if (Check-WSL2) {
    Write-Host "Enabling WSL2 support for Docker..."
    & "C:\Program Files\Docker\Docker\resources\com.docker.backend.exe" --wsl --set-default
}

# Ensure Docker Engine is running
Write-Host "Checking Docker status..."
$dockerRunning = $false
$attempts = 0
while (-not $dockerRunning -and $attempts -lt 10) {
    Start-Sleep -Seconds 10
    try {
        docker info | Out-Null
        $dockerRunning = $true
    } catch {
        Write-Host "Waiting for Docker to be ready..."
        $attempts++
    }
}

if (-not $dockerRunning) {
    Write-Host "Docker failed to start. Please check your installation."
    exit 1
}

# Pull and run Portainer
Write-Host "Pulling and launching Portainer..."
docker volume create portainer_data
docker run -d --name=portainer --restart=always -p 8000:8000 -p 9000:9000 -p 9443:9443 `
    -v /var/run/docker.sock:/var/run/docker.sock `
    -v portainer_data:/data `
    portainer/portainer-ce

Write-Host "Portainer is now running at https://localhost:9443"
