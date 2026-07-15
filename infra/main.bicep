@description('Azure SRE Agent Demo — root Bicep template')
param location string = 'eastus2'
param prefix string = 'sre-demo'
param alertEmail string

@description('Fresh GUID generated at every deployment — becomes the ADMIN_TOKEN')
param adminToken string = newGuid()

// ── Resource names ────────────────────────────────────────────────────────────
var lawName = '${prefix}-law'
var appInsightsName = '${prefix}-ai'
var planName = '${prefix}-plan'
var appName = '${prefix}-app'
var actionGroupName = '${prefix}-alerts'

// ── Log Analytics Workspace ───────────────────────────────────────────────────
module law './modules/loganalytics.bicep' = {
  name: 'deploy-law'
  params: {
    location: location
    name: lawName
  }
}

// ── Application Insights (workspace-based) ────────────────────────────────────
module appInsights './modules/appinsights.bicep' = {
  name: 'deploy-appinsights'
  params: {
    location: location
    name: appInsightsName
    logAnalyticsWorkspaceId: law.outputs.id
  }
}

// ── Action Group ──────────────────────────────────────────────────────────────
module actionGroup './modules/actiongroup.bicep' = {
  name: 'deploy-actiongroup'
  params: {
    name: actionGroupName
    alertEmail: alertEmail
  }
}

// ── App Service Plan + App ────────────────────────────────────────────────────
module appService './modules/appservice.bicep' = {
  name: 'deploy-appservice'
  params: {
    location: location
    appServicePlanName: planName
    appServiceName: appName
    appInsightsConnectionString: appInsights.outputs.connectionString
    adminToken: adminToken
  }
}

// ── Alert Rules ───────────────────────────────────────────────────────────────
module alerts './modules/alerts.bicep' = {
  name: 'deploy-alerts'
  params: {
    appInsightsId: appInsights.outputs.id
    actionGroupId: actionGroup.outputs.id
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────
output appServiceName string = appService.outputs.appServiceName
output appUrl string = 'https://${appService.outputs.defaultHostName}'
output appInsightsConnectionString string = appInsights.outputs.connectionString
output logAnalyticsWorkspaceId string = law.outputs.id

@description('Retrieve ADMIN_TOKEN with: az webapp config appsettings list -g <rg> -n <appServiceName> --query "[?name==\'ADMIN_TOKEN\'].value" -o tsv')
output adminTokenNote string = 'Run: az webapp config appsettings list -g rg-sre-demo -n <appServiceName> --query "[?name==\'ADMIN_TOKEN\'].value" -o tsv'
