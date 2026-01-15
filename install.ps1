# PowerShell script equivalent to 'make install' for Windows

Write-Host "Installing MCP Flutter Inspector Server..." -ForegroundColor Green

# Navigate to mcp_server_dart directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$mcpServerPath = Join-Path $scriptPath "mcp_server_dart"

if (-not (Test-Path $mcpServerPath)) {
    Write-Host "Error: mcp_server_dart directory not found!" -ForegroundColor Red
    exit 1
}

Set-Location $mcpServerPath

# Run flutter pub get
Write-Host "Running 'flutter pub get'..." -ForegroundColor Yellow
fvm flutter pub get

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: 'flutter pub get' failed!" -ForegroundColor Red
    exit 1
}

# Create build directory if it doesn't exist
$buildDir = Join-Path $mcpServerPath "build"
if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir | Out-Null
}

# Compile the executable
Write-Host "Compiling executable..." -ForegroundColor Yellow
fvm dart compile exe bin/main.dart -o build/flutter_inspector_mcp.exe

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Compilation failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "Executable created at: $buildDir\flutter_inspector_mcp.exe" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure your AI assistant (Cursor, Claude, etc.) to use:" -ForegroundColor White
Write-Host "   $buildDir\flutter_inspector_mcp.exe" -ForegroundColor Cyan
Write-Host "2. For Flutter Web apps, use initializeWebBridgeForWeb() in main.dart" -ForegroundColor White
Write-Host "3. For Mobile/Desktop apps, use initialize() in main.dart" -ForegroundColor White
Write-Host "4. Restart your AI assistant after configuration" -ForegroundColor White

