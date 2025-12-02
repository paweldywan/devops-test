<#
.SYNOPSIS
    Sets up Azure Monitor with Application Insights and CPU alert rules for an App Service.

.DESCRIPTION
    This script creates:
    - Log Analytics Workspace
    - Application Insights (workspace-based)
    - Action Group for alert notifications
    - CPU percentage alert rule
    - Memory percentage alert rule
    - HTTP 5xx error alert rule

.PARAMETER ResourceGroupName
    The name of the resource group containing the App Service.

.PARAMETER WebAppName
    The name of the Azure Web App to monitor.

.PARAMETER Location
    The Azure region for resources. Defaults to 'eastus'.

.PARAMETER AlertEmailAddress
    Email address for alert notifications.

.EXAMPLE
    .\monitoring-setup.ps1 -ResourceGroupName "rg-myapp-dev" -WebAppName "webapp-myapp-dev" -AlertEmailAddress "admin@example.com"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$WebAppName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $true)]
    [string]$AlertEmailAddress
)

# Set strict mode and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Color output helper
function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    switch ($Type) {
        "Success" { Write-Host "✓ $Message" -ForegroundColor Green }
        "Warning" { Write-Host "⚠ $Message" -ForegroundColor Yellow }
        "Error"   { Write-Host "✗ $Message" -ForegroundColor Red }
        default   { Write-Host "→ $Message" -ForegroundColor Cyan }
    }
}

# Naming conventions
$logAnalyticsName = "log-$WebAppName"
$appInsightsName = "appi-$WebAppName"
$actionGroupName = "ag-$WebAppName-alerts"

try {
    Write-Status "Starting Azure Monitor setup for $WebAppName..."

    # Verify Azure CLI login
    Write-Status "Verifying Azure CLI authentication..."
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        throw "Not logged into Azure CLI. Please run 'az login' first."
    }
    Write-Status "Using subscription: $($account.name)" -Type "Success"

    # Verify Web App exists
    Write-Status "Verifying Web App exists..."
    $webApp = az webapp show --name $WebAppName --resource-group $ResourceGroupName 2>$null | ConvertFrom-Json
    if (-not $webApp) {
        throw "Web App '$WebAppName' not found in resource group '$ResourceGroupName'."
    }
    $webAppResourceId = $webApp.id
    Write-Status "Found Web App: $WebAppName" -Type "Success"

    # Create Log Analytics Workspace
    Write-Status "Creating Log Analytics Workspace: $logAnalyticsName..."
    az monitor log-analytics workspace create `
        --resource-group $ResourceGroupName `
        --workspace-name $logAnalyticsName `
        --location $Location `
        --retention-time 30 `
        --output none

    $logAnalytics = az monitor log-analytics workspace show `
        --resource-group $ResourceGroupName `
        --workspace-name $logAnalyticsName | ConvertFrom-Json
    Write-Status "Log Analytics Workspace created" -Type "Success"

    # Create Application Insights (workspace-based)
    Write-Status "Creating Application Insights: $appInsightsName..."
    az monitor app-insights component create `
        --app $appInsightsName `
        --location $Location `
        --resource-group $ResourceGroupName `
        --workspace $logAnalytics.id `
        --application-type web `
        --output none

    $appInsights = az monitor app-insights component show `
        --app $appInsightsName `
        --resource-group $ResourceGroupName | ConvertFrom-Json
    Write-Status "Application Insights created" -Type "Success"

    # Configure App Service to use Application Insights
    Write-Status "Configuring App Service with Application Insights..."
    az webapp config appsettings set `
        --name $WebAppName `
        --resource-group $ResourceGroupName `
        --settings `
            APPLICATIONINSIGHTS_CONNECTION_STRING=$($appInsights.connectionString) `
            ApplicationInsightsAgent_EXTENSION_VERSION="~3" `
            XDT_MicrosoftApplicationInsights_Mode="Recommended" `
        --output none
    Write-Status "App Service configured with Application Insights" -Type "Success"

    # Create Action Group for alerts
    Write-Status "Creating Action Group: $actionGroupName..."
    az monitor action-group create `
        --resource-group $ResourceGroupName `
        --name $actionGroupName `
        --short-name "AppAlerts" `
        --action email AdminEmail $AlertEmailAddress `
        --output none

    $actionGroup = az monitor action-group show `
        --resource-group $ResourceGroupName `
        --name $actionGroupName | ConvertFrom-Json
    
    if (-not $actionGroup) {
        throw "Failed to create Action Group"
    }
    Write-Status "Action Group created" -Type "Success"

    # Get App Service Plan for CPU/Memory metrics
    Write-Status "Getting App Service Plan..."
    $appServicePlanId = $webApp.appServicePlanId
    Write-Status "Found App Service Plan" -Type "Success"

    # Create CPU Alert Rule (> 80% for 5 minutes) - scoped to App Service Plan
    Write-Status "Creating CPU percentage alert rule..."
    az monitor metrics alert create `
        --name "alert-cpu-high-$WebAppName" `
        --resource-group $ResourceGroupName `
        --scopes $appServicePlanId `
        --condition "avg CpuPercentage > 80" `
        --window-size 5m `
        --evaluation-frequency 1m `
        --severity 2 `
        --description "Alert when CPU exceeds 80% for 5 minutes" `
        --action $actionGroup.id `
        --output none
    Write-Status "CPU alert rule created (threshold: 80%)" -Type "Success"

    # Create Memory Alert Rule (> 85% for 5 minutes) - scoped to App Service Plan
    Write-Status "Creating memory percentage alert rule..."
    az monitor metrics alert create `
        --name "alert-memory-high-$WebAppName" `
        --resource-group $ResourceGroupName `
        --scopes $appServicePlanId `
        --condition "avg MemoryPercentage > 85" `
        --window-size 5m `
        --evaluation-frequency 1m `
        --severity 2 `
        --description "Alert when memory exceeds 85% for 5 minutes" `
        --action $actionGroup.id `
        --output none
    Write-Status "Memory alert rule created (threshold: 85%)" -Type "Success"

    # Create HTTP 5xx Error Alert Rule
    Write-Status "Creating HTTP 5xx error alert rule..."
    az monitor metrics alert create `
        --name "alert-http5xx-$WebAppName" `
        --resource-group $ResourceGroupName `
        --scopes $webAppResourceId `
        --condition "total Http5xx > 10" `
        --window-size 5m `
        --evaluation-frequency 1m `
        --severity 1 `
        --description "Alert when HTTP 5xx errors exceed 10 in 5 minutes" `
        --action $actionGroup.id `
        --output none
    Write-Status "HTTP 5xx alert rule created (threshold: 10 errors)" -Type "Success"

    # Create Response Time Alert Rule (> 5 seconds average)
    Write-Status "Creating response time alert rule..."
    az monitor metrics alert create `
        --name "alert-response-time-$WebAppName" `
        --resource-group $ResourceGroupName `
        --scopes $webAppResourceId `
        --condition "avg HttpResponseTime > 5" `
        --window-size 5m `
        --evaluation-frequency 1m `
        --severity 3 `
        --description "Alert when average response time exceeds 5 seconds" `
        --action $actionGroup.id `
        --output none
    Write-Status "Response time alert rule created (threshold: 5s)" -Type "Success"

    # Enable diagnostic settings to send logs to Log Analytics
    Write-Status "Enabling diagnostic settings..."
    $logsConfig = '[{\"category\":\"AppServiceHTTPLogs\",\"enabled\":true},{\"category\":\"AppServiceConsoleLogs\",\"enabled\":true},{\"category\":\"AppServiceAppLogs\",\"enabled\":true}]'
    $metricsConfig = '[{\"category\":\"AllMetrics\",\"enabled\":true}]'
    
    az monitor diagnostic-settings create `
        --name "diag-$WebAppName" `
        --resource $webAppResourceId `
        --workspace $logAnalytics.id `
        --logs $logsConfig `
        --metrics $metricsConfig `
        --output none
    Write-Status "Diagnostic settings enabled" -Type "Success"

    # Summary
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Monitoring Setup Complete!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Resources Created:"
    Write-Host "  • Log Analytics Workspace: $logAnalyticsName"
    Write-Host "  • Application Insights: $appInsightsName"
    Write-Host "  • Action Group: $actionGroupName"
    Write-Host ""
    Write-Host "Alert Rules Created:"
    Write-Host "  • CPU > 80% (Severity 2)"
    Write-Host "  • Memory > 85% (Severity 2)"
    Write-Host "  • HTTP 5xx > 10 errors (Severity 1)"
    Write-Host "  • Response Time > 5s (Severity 3)"
    Write-Host ""
    Write-Host "Alerts will be sent to: $AlertEmailAddress"
    Write-Host ""
    Write-Host "View in Azure Portal:"
    Write-Host "  https://portal.azure.com/#@/resource$webAppResourceId/monitoring"
    Write-Host "============================================" -ForegroundColor Green

} catch {
    Write-Status "Error: $($_.Exception.Message)" -Type "Error"
    exit 1
}
