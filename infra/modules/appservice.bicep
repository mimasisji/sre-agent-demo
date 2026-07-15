@description('App Service Plan + App Service for SRE Agent Demo')
param location string
param appServicePlanName string
param appServiceName string
param appInsightsConnectionString string
param adminToken string

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'F1'
    tier: 'Free'
  }
  properties: {
    reserved: true  // required for Linux
  }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appServiceName
  location: location
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|8.0'
      alwaysOn: false   // B1 does not support Always On
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'ENABLE_FAILURE_MODE'
          value: 'false'
        }
        {
          name: 'ENABLE_DB_TIMEOUT'
          value: 'false'
        }
        {
          name: 'DEPLOYMENT_VERSION'
          value: 'initial'
        }
        {
          name: 'ADMIN_TOKEN'
          value: adminToken
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Production'
        }
      ]
    }
  }
}

output appServiceName string = app.name
output defaultHostName string = app.properties.defaultHostName
output appServiceId string = app.id
