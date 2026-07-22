param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9-]+$')]
  [string]$ProjectId,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$WebApiKey,

  [string]$ProductionProjectId = 'flutter-flow-pipe'
)

$ErrorActionPreference = 'Stop'

if ($ProjectId -eq $ProductionProjectId) {
  throw 'The safe-default rehearsal must never run against production.'
}
if ($ProjectId -match '(^|-)prod(uction)?($|-)') {
  throw "Project '$ProjectId' looks like production. Use isolated staging."
}

function Invoke-JsonRequest {
  param(
    [Parameter(Mandatory = $true)][ValidateSet('GET', 'POST')][string]$Method,
    [Parameter(Mandatory = $true)][string]$Uri,
    [hashtable]$Headers = @{},
    [object]$Body
  )

  $arguments = @{
    Method = $Method
    Uri = $Uri
    Headers = $Headers
    SkipHttpErrorCheck = $true
  }
  if ($null -ne $Body) {
    $arguments.ContentType = 'application/json'
    $arguments.Body = $Body | ConvertTo-Json -Depth 20 -Compress
  }
  $response = Invoke-WebRequest @arguments
  $parsedBody = $null
  if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
    try {
      $parsedBody = $response.Content | ConvertFrom-Json
    } catch {
      $parsedBody = $response.Content
    }
  }
  return [pscustomobject]@{
    StatusCode = [int]$response.StatusCode
    Body = $parsedBody
  }
}

function Assert-DeniedWrite {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Collection,
    [Parameter(Mandatory = $true)][string]$DocumentId,
    [Parameter(Mandatory = $true)][hashtable]$Fields,
    [Parameter(Mandatory = $true)][string]$IdToken
  )

  $encodedDocumentId = [uri]::EscapeDataString($DocumentId)
  $uri = "https://firestore.googleapis.com/v1/projects/$ProjectId/databases/(default)/documents/$Collection`?documentId=$encodedDocumentId"
  $response = Invoke-JsonRequest -Method POST -Uri $uri -Headers @{
    Authorization = "Bearer $IdToken"
  } -Body @{ fields = $Fields }
  if ($response.StatusCode -notin @(401, 403)) {
    throw "$Name was not denied. Firestore returned HTTP $($response.StatusCode)."
  }
  return [pscustomobject]@{
    control = $Name
    collection = $Collection
    statusCode = $response.StatusCode
    denied = $true
  }
}

$identityBase = "https://identitytoolkit.googleapis.com/v1/accounts"
$firestoreBase = "https://firestore.googleapis.com/v1/projects/$ProjectId/databases/(default)/documents"
$runId = [guid]::NewGuid().ToString('N')
$email = "phase1-safe-default-$runId@example.invalid"
$password = "P1!$([guid]::NewGuid().ToString('N'))z9"
$idToken = $null
$localId = $null
$checks = [System.Collections.Generic.List[object]]::new()

try {
  $configuration = Invoke-JsonRequest -Method GET `
    -Uri "$firestoreBase/platform_configuration/phase1_features"
  if ($configuration.StatusCode -ne 404) {
    throw (
      'This rehearsal proves the missing-configuration safe default and ' +
      "requires the phase1_features document to be absent. HTTP $($configuration.StatusCode)."
    )
  }
  $checks.Add([pscustomobject]@{
    control = 'Missing runtime configuration'
    statusCode = 404
    safeDefaultCase = $true
  })

  $signup = Invoke-JsonRequest -Method POST `
    -Uri "$identityBase`:signUp?key=$([uri]::EscapeDataString($WebApiKey))" `
    -Body @{
      email = $email
      password = $password
      returnSecureToken = $true
    }
  if ($signup.StatusCode -ne 200 -or
      [string]::IsNullOrWhiteSpace([string]$signup.Body.idToken) -or
      [string]::IsNullOrWhiteSpace([string]$signup.Body.localId)) {
    throw "Could not create the disposable staging identity (HTTP $($signup.StatusCode))."
  }
  $idToken = [string]$signup.Body.idToken
  $localId = [string]$signup.Body.localId

  $commonListingFields = @{
    sellerUid = @{ stringValue = $localId }
    status = @{ stringValue = 'active' }
    title = @{ stringValue = 'Safe-default rehearsal' }
    updatedAt = @{ timestampValue = [DateTime]::UtcNow.ToString('o') }
  }

  $checks.Add((Assert-DeniedWrite `
    -Name 'Marketplace direct create without configuration' `
    -Collection 'public_listings' `
    -DocumentId "rehearsal-marketplace-$runId" `
    -IdToken $idToken `
    -Fields ($commonListingFields + @{
      transactionType = @{ stringValue = 'For Sale' }
      category = @{ stringValue = 'Heavy Equipment' }
    })))
  $checks.Add((Assert-DeniedWrite `
    -Name 'Auction direct create without configuration' `
    -Collection 'public_listings' `
    -DocumentId "rehearsal-auction-$runId" `
    -IdToken $idToken `
    -Fields ($commonListingFields + @{
      transactionType = @{ stringValue = 'Auction' }
      category = @{ stringValue = 'Heavy Equipment' }
    })))
  $checks.Add((Assert-DeniedWrite `
    -Name 'Regulated property direct create without configuration' `
    -Collection 'public_listings' `
    -DocumentId "rehearsal-regulated-$runId" `
    -IdToken $idToken `
    -Fields ($commonListingFields + @{
      transactionType = @{ stringValue = 'For Sale' }
      category = @{ stringValue = 'Site & Property' }
    })))
  $checks.Add((Assert-DeniedWrite `
    -Name 'Paid boost direct create without configuration' `
    -Collection 'public_listings' `
    -DocumentId "rehearsal-paid-$runId" `
    -IdToken $idToken `
    -Fields ($commonListingFields + @{
      transactionType = @{ stringValue = 'For Sale' }
      category = @{ stringValue = 'Heavy Equipment' }
      boostRequested = @{ booleanValue = $true }
      boostPrice = @{ integerValue = '100' }
    })))
  $checks.Add((Assert-DeniedWrite `
    -Name 'Dispatch carrier direct create without configuration' `
    -Collection 'dispatch_carriers' `
    -DocumentId $localId `
    -IdToken $idToken `
    -Fields @{
      ownerUid = @{ stringValue = $localId }
      operatingName = @{ stringValue = 'Safe-default rehearsal' }
    }))

  [ordered]@{
    projectId = $ProjectId
    productionProjectProtected = $true
    runtimeConfigurationAbsent = $true
    disposableIdentityCreated = $true
    checks = $checks
    passed = $true
  } | ConvertTo-Json -Depth 10
} finally {
  if ($idToken) {
    $delete = Invoke-JsonRequest -Method POST `
      -Uri "$identityBase`:delete?key=$([uri]::EscapeDataString($WebApiKey))" `
      -Body @{ idToken = $idToken }
    if ($delete.StatusCode -ne 200) {
      Write-Warning (
        'The rehearsal finished, but disposable identity cleanup returned ' +
        "HTTP $($delete.StatusCode). Remove UID $localId from isolated staging."
      )
    } else {
      Write-Host 'Disposable staging identity removed.'
    }
  }
}
