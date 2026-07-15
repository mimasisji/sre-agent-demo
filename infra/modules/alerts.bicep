@description('Azure Monitor alert rules for SRE Agent Demo')
param appInsightsId string
param actionGroupId string

// ── Alert 1: HTTP 500 Spike ───────────────────────────────────────────────────
resource http500Alert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'sre-demo-http500-spike'
  location: resourceGroup().location
  properties: {
    displayName: 'HTTP500 Spike — SRE Demo'
    description: 'Fires when more than 5 HTTP 500 responses occur in any 10-minute window.'
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    severity: 1
    scopes: [appInsightsId]
    criteria: {
      allOf: [
        {
          query: '''
requests
| where resultCode == "500"
| summarize count() by bin(timestamp, 5m)
| where count_ > 5
'''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
    }
    autoMitigate: true
  }
}

// ── Alert 2: High Latency ─────────────────────────────────────────────────────
resource highLatencyAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'sre-demo-high-latency'
  location: resourceGroup().location
  properties: {
    displayName: 'High Latency — SRE Demo'
    description: 'Fires when average response time exceeds 2000ms over a 10-minute window.'
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    severity: 2
    scopes: [appInsightsId]
    criteria: {
      allOf: [
        {
          query: '''
requests
| summarize avg_duration = avg(duration) by bin(timestamp, 5m)
| where avg_duration > 2000
'''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
    }
    autoMitigate: true
  }
}

// ── Alert 3: Failed Request Rate ──────────────────────────────────────────────
resource failedRequestRateAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'sre-demo-failed-request-rate'
  location: resourceGroup().location
  properties: {
    displayName: 'Failed Request Rate > 10% — SRE Demo'
    description: 'Fires when the failed request rate exceeds 10% of total traffic.'
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    severity: 2
    scopes: [appInsightsId]
    criteria: {
      allOf: [
        {
          query: '''
requests
| summarize failed = countif(success == false), total = count() by bin(timestamp, 5m)
| extend rate = todouble(failed) / total
| where rate > 0.1
'''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [actionGroupId]
    }
    autoMitigate: true
  }
}
