@description('Log Analytics Workspace for SRE Agent Demo')
param location string
param name string
param retentionDays int = 30

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

output id string = law.id
output name string = law.name
output customerId string = law.properties.customerId
