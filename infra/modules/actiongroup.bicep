@description('Action Group for alert notifications')
param location string = 'global'
param name string
param alertEmail string

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: name
  location: location
  properties: {
    groupShortName: 'SREAlerts'
    enabled: true
    emailReceivers: [
      {
        name: 'OnCallEmail'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

output id string = actionGroup.id
