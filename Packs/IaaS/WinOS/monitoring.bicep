targetScope = 'managementGroup'
@description('The Tag value for this pack')
param packtag string = 'WinOS'
@description('Name of the DCR rule to be created')
param rulename string = 'AMSP-Windows-OS'
@description('Name of the Action Group to be used or created.')
param actionGroupName string
@description('Email receiver names to be used for the Action Group if being created.')
param emailreceiver string = ''
@description('Email addresses to be used for the Action Group if being created.')
param emailreiceversemail string  = ''
@description('If set to true, a new Action group will be created')
param useExistingAG bool = false
@description('Name of the existing resource group to be used for the Action Group if existing.')
param existingAGRG string = ''
@description('location for the deployment.')
param location string //= resourceGroup().location
@description('Full resource ID of the log analytics workspace to be used for the deployment.')
param workspaceId string
param solutionTag string
param solutionVersion string
param dceId string
param userManagedIdentityResourceId string
param mgname string // this the last part of the management group id
param subscriptionId string
param resourceGroupId string
param assignmentLevel string
param grafanaName string
param customerTags object
var Tags = union({
  '${solutionTag}': packtag
  'solutionVersion': solutionVersion
},customerTags)
var ruleshortname = 'VMI-OS'
var resourceGroupName = split(resourceGroupId, '/')[4]

// Action Group
module ag '../../../modules/actiongroups/ag.bicep' =  {
  name: 'actiongroup'
  params: {
    actionGroupName: actionGroupName
    existingAGRG: existingAGRG
    emailreceiver: emailreceiver
    emailreiceversemail: emailreiceversemail
    useExistingAG: useExistingAG
    newRGresourceGroup: resourceGroupName
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    location: location
    Tags: Tags
    //location: location defailt is global
  }
}

// // Alerts - Event viewer based alerts. Depend on the event viewer logs being enabled on the VMs events are being sent to the workspace via DCRs.
// module eventAlerts 'eventAlerts.bicep' = {
//   name: 'eventAlerts-${packtag}'
//   params: {
//     AGId: ag.outputs.actionGroupResourceId
//     location: location
//     workspaceId: workspaceId
//     packtag: packtag
//     solutionTag: solutionTag
//     solutionVersion: solutionVersion

//   }
// } 

// This option uses an existing VMI rule but this can be a tad problematic.
// resource vmInsightsDCR 'Microsoft.Insights/dataCollectionRules@2021-09-01-preview' existing = if(enableInsightsAlerts == 'true') {
//   name: insightsRuleName
//   scope: resourceGroup(insightsRuleRg)
// }
// So, let's create an Insights rule for the VMs that should be the same as the usual VMInsights.

module vmInsightsDCR '../../../modules/DCRs/DefaultVMI-rule.bicep' = {
  name: 'vmInsightsDCR-${packtag}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    location: location
    workspaceResourceId: workspaceId
    Tags: Tags
    ruleName: rulename
    dceId: dceId
  }
}

module InsightsAlerts './VMInsightsAlerts.bicep' = {
  name: 'Alerts-${packtag}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    location: location
    workspaceId: workspaceId
    AGId: ag.outputs.actionGroupResourceId
    packtag: packtag
    Tags: Tags
  }
}

module policysetup '../../../modules/policies/mg/policies.bicep' = {
  name: 'policysetup-${packtag}'
  scope: managementGroup(mgname)
  params: {
    dcrId: vmInsightsDCR.outputs.VMIRuleId
    packtag: packtag
    solutionTag: solutionTag
    rulename: rulename
    location: location
    userManagedIdentityResourceId: userManagedIdentityResourceId
    mgname: mgname
    ruleshortname: ruleshortname
    assignmentLevel: assignmentLevel
    subscriptionId: subscriptionId
  }
}
// // Grafana upload and install
// module grafana 'ds.bicep' = {
//   name: 'grafana'
//   scope: resourceGroup(subscriptionId, resourceGroupName)
//   params: {
//     fileName: 'grafana.json'
//     grafanaName: grafanaName
//     location: location
//     resourceGroupName: resourceGroupName
//     solutionTag: solutionTag
//     solutionVersion: solutionVersion
//     packsManagedIdentityResourceId: userManagedIdentityResourceId
//   }
// }

// Azure recommended Alerts for VMs
// These are the (very) basic recommeded alerts for VM, based on platform metrics
// module vmrecommended 'AzureBasicMetricAlerts.bicep' = if (enableBasicVMPlatformAlerts) {
//   name: 'vmrecommended'
//   params: {
//     vmIDs: vmIDs
//     packtag: packtag
//     solutionTag: solutionTag
//   }
// }
