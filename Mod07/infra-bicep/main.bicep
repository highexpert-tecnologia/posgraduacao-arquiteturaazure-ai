// =============================================================================
// Mod07 - Lab de Observabilidade (jornada de mensagem)
// Fluxo: APIM -> Function Producer -> Service Bus -> Function Consumer -> Blob + Cosmos
//        tudo correlacionado em um unico Application Insights.
//
// Infra SELF-CONTAINED: provisiona TUDO do zero (APIM, Service Bus, Storage,
// Cosmos, App Insights, 2 Function Apps e RBAC). Escopo: resource group.
//
// Autenticacao de dados: Managed Identity + RBAC (sem connection string p/ dados).
//   - Producer MI  -> Azure Service Bus Data Sender   (namespace)
//   - Consumer MI  -> Azure Service Bus Data Receiver (namespace)
//                  -> Storage Blob Data Contributor   (storage)
//                  -> Cosmos DB Built-in Data Contributor (data plane)
// =============================================================================

targetScope = 'resourceGroup'

// ----------------------------- Parametros ------------------------------------

@description('Regiao principal dos recursos (Functions, App Insights, Service Bus, Storage, APIM).')
param location string = resourceGroup().location

@description('Regiao do Cosmos DB. East US 2 por padrao (East US deu ServiceUnavailable de capacidade no lab).')
param cosmosLocation string = 'eastus2'

@description('Prefixo base para nomear os recursos (apenas minusculas/numeros). Ex.: mod07.')
@minLength(3)
@maxLength(10)
param namePrefix string = 'mod07'

@description('Email do publisher do APIM.')
param publisherEmail string = 'hsouza.eduardo@gmail.com'

@description('Nome do publisher do APIM.')
param publisherName string = 'Mod07 Lab'

@description('SKU do APIM. Consumption deploya em minutos e custa pouco (ideal p/ lab). Developer p/ recursos completos (~45min).')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Standard'
])
param apimSku string = 'Consumption'

@description('Nome da fila do Service Bus.')
param queueName string = 'mod07-msgjourney'

@description('Nome do container de blobs onde o Consumer arquiva os envelopes.')
param blobContainerName string = 'messages'

@description('Nome do database Cosmos.')
param cosmosDatabaseName string = 'mod07'

@description('Nome do container Cosmos (PK /correlationId).')
param cosmosContainerName string = 'pedidos'

@description('Tags aplicadas a todos os recursos.')
param tags object = {
  projeto: 'mod07-observabilidade'
  ambiente: 'lab'
}

// ------------------------------ Nomes ----------------------------------------

var suffix = uniqueString(resourceGroup().id)

var laName       = 'log-${namePrefix}-${take(suffix, 6)}'
var aiName       = 'appi-${namePrefix}-${take(suffix, 6)}'
var sbNamespace  = 'sb-${namePrefix}-${take(suffix, 6)}'
var storageName  = take(toLower(replace('st${namePrefix}${suffix}', '-', '')), 24)
var cosmosName   = 'cosmos-${namePrefix}-${take(suffix, 6)}'
var planName     = 'plan-${namePrefix}-${take(suffix, 6)}'
var producerName = 'func-${namePrefix}-producer-${take(suffix, 6)}'
var consumerName = 'func-${namePrefix}-consumer-${take(suffix, 6)}'
var apimName     = 'apim-${namePrefix}-${take(suffix, 6)}'

// IDs de roles internos (built-in)
var roleSbDataSender   = '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39' // Azure Service Bus Data Sender
var roleSbDataReceiver = '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0' // Azure Service Bus Data Receiver
var roleBlobDataContrib = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
var roleCosmosDataContrib = '00000000-0000-0000-0000-000000000002' // Cosmos DB Built-in Data Contributor (data plane)

// =============================================================================
// Observabilidade: Log Analytics + Application Insights (workspace-based)
// =============================================================================

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: laName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: aiName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: law.id
    IngestionMode: 'LogAnalytics'
  }
}

// =============================================================================
// Service Bus: namespace + fila
// =============================================================================

resource sb 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: sbNamespace
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

resource queue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: sb
  name: queueName
  properties: {
    maxDeliveryCount: 10
    lockDuration: 'PT1M'
    deadLetteringOnMessageExpiration: true
  }
}

// =============================================================================
// Storage: conta + container 'messages'
// (serve tambem de AzureWebJobsStorage do host das Functions, via connection string)
// =============================================================================

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource messagesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: blobContainerName
}

var storageConnString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'

// =============================================================================
// Cosmos DB SQL serverless: account + database + container (PK /correlationId)
// =============================================================================

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: cosmosName
  location: cosmosLocation
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    locations: [
      {
        locationName: cosmosLocation
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      { name: 'EnableServerless' }
    ]
    disableLocalAuth: false
  }
}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  parent: cosmos
  name: cosmosDatabaseName
  properties: {
    resource: { id: cosmosDatabaseName }
  }
}

resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  parent: cosmosDb
  name: cosmosContainerName
  properties: {
    resource: {
      id: cosmosContainerName
      partitionKey: {
        paths: [ '/correlationId' ]
        kind: 'Hash'
      }
    }
  }
}

// =============================================================================
// Plano de hospedagem (Consumption Y1, Linux) + 2 Function Apps (.NET 8 isolated)
// =============================================================================

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'functionapp'
  properties: {
    reserved: true // Linux
  }
}

// App settings comuns aos dois apps
var commonAppSettings = [
  { name: 'AzureWebJobsStorage', value: storageConnString }
  { name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING', value: storageConnString }
  { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
  { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'dotnet-isolated' }
  { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
  { name: 'ServiceBusConnection__fullyQualifiedNamespace', value: '${sbNamespace}.servicebus.windows.net' }
  { name: 'QUEUE_NAME', value: queueName }
]

resource producer 'Microsoft.Web/sites@2023-12-01' = {
  name: producerName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    reserved: true
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: concat(commonAppSettings, [
        { name: 'WEBSITE_CONTENTSHARE', value: toLower(producerName) }
      ])
    }
  }
}

resource consumer 'Microsoft.Web/sites@2023-12-01' = {
  name: consumerName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    reserved: true
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: concat(commonAppSettings, [
        { name: 'WEBSITE_CONTENTSHARE', value: toLower(consumerName) }
        { name: 'STORAGE_BLOB_URI', value: storage.properties.primaryEndpoints.blob }
        { name: 'BLOB_CONTAINER', value: blobContainerName }
        { name: 'COSMOS_ENDPOINT', value: cosmos.properties.documentEndpoint }
        { name: 'COSMOS_DATABASE', value: cosmosDatabaseName }
        { name: 'COSMOS_CONTAINER', value: cosmosContainerName }
      ])
    }
  }
}

// =============================================================================
// RBAC (data plane via Managed Identity)
// =============================================================================

// Producer -> Service Bus Data Sender (namespace)
resource raProducerSbSender 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sb.id, producer.id, roleSbDataSender)
  scope: sb
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleSbDataSender)
    principalId: producer.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Consumer -> Service Bus Data Receiver (namespace)
resource raConsumerSbReceiver 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sb.id, consumer.id, roleSbDataReceiver)
  scope: sb
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleSbDataReceiver)
    principalId: consumer.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Consumer -> Storage Blob Data Contributor (storage)
resource raConsumerBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, consumer.id, roleBlobDataContrib)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleBlobDataContrib)
    principalId: consumer.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Consumer -> Cosmos DB Built-in Data Contributor (data plane / SQL role assignment)
resource raConsumerCosmos 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  parent: cosmos
  name: guid(cosmos.id, consumer.id, roleCosmosDataContrib)
  properties: {
    roleDefinitionId: '${cosmos.id}/sqlRoleDefinitions/${roleCosmosDataContrib}'
    principalId: consumer.identity.principalId
    scope: cosmos.id
  }
}

// =============================================================================
// APIM: servico + named value (chave da Function) + API + operacao + policy + subscription
// =============================================================================

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: apimSku
    capacity: apimSku == 'Consumption' ? 0 : 1
  }
  identity: { type: 'SystemAssigned' }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// Named value (secret) com a chave de funcao do Producer.
// Obs.: a host key 'default' e gerada na criacao do app; se o APIM retornar 401 no
// primeiro teste (key ainda nao materializada), basta atualizar este named value
// apos o primeiro 'func publish'.
resource nvProducerKey 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  parent: apim
  name: 'func-mod07-producer-key'
  properties: {
    displayName: 'func-mod07-producer-key'
    secret: true
    value: listKeys(resourceId('Microsoft.Web/sites/host', producer.name, 'default'), '2023-12-01').functionKeys.default
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: 'mod07-producer'
  properties: {
    displayName: 'Mod07 Producer'
    path: 'mod07'
    protocols: [ 'https' ]
    subscriptionRequired: true
    serviceUrl: 'https://${producer.properties.defaultHostName}/api'
  }
}

resource apiOpSend 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: api
  name: 'send'
  properties: {
    displayName: 'Send'
    method: 'POST'
    urlTemplate: '/send'
  }
}

var producerPolicyXml = '''
<policies>
  <inbound>
    <base />
    <set-header name="x-functions-key" exists-action="override">
      <value>{{func-mod07-producer-key}}</value>
    </set-header>
    <set-header name="x-apim-correlation-id" exists-action="skip">
      <value>@(context.RequestId.ToString())</value>
    </set-header>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'''

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: producerPolicyXml
  }
  dependsOn: [ nvProducerKey ]
}

resource sub 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = {
  parent: apim
  name: 'mod07-sub'
  properties: {
    displayName: 'Mod07 Lab Subscription'
    scope: api.id
    state: 'active'
  }
}

// =============================================================================
// Outputs
// =============================================================================

output resourceGroupName string = resourceGroup().name
output appInsightsName string = appInsights.name
output serviceBusNamespace string = sb.name
output queue string = queueName
output storageAccount string = storage.name
output cosmosAccount string = cosmos.name
output producerFunctionApp string = producer.name
output consumerFunctionApp string = consumer.name
output apimName string = apim.name

@description('Endpoint de teste do lab (use o header Ocp-Apim-Subscription-Key).')
output testEndpoint string = '${apim.properties.gatewayUrl}/mod07/send'

@description('Comando para obter a chave da subscription do APIM.')
output getSubscriptionKeyCmd string = 'az apim subscription show -g ${resourceGroup().name} --service-name ${apim.name} --sid mod07-sub --query primaryKey -o tsv'
