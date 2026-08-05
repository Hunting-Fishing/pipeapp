param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^https?://')]
  [string]$Url,

  [string]$ScreenshotPath = 'build/acceptance/web-mobile-smoke.png',

  [ValidateRange(10, 90)]
  [int]$TimeoutSeconds = 35,

  [ValidateRange(320, 1600)]
  [int]$ViewportWidth = 390,

  [ValidateRange(480, 2000)]
  [int]$ViewportHeight = 844,

  [ValidateRange(1, 15)]
  [int]$StabilizationSeconds = 5,

  [string]$ExpectedTextPattern = 'Pipe Buyer',

  [string]$AppCheckDebugToken = $env:PIPE_APP_CHECK_WEB_DEBUG_TOKEN
)

$ErrorActionPreference = 'Stop'

function Resolve-BrowserPath {
  $candidates = @(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }
  throw 'Chrome or Microsoft Edge is required for the web visual smoke test.'
}

function Get-FreeTcpPort {
  $listener = [System.Net.Sockets.TcpListener]::new(
    [System.Net.IPAddress]::Loopback,
    0
  )
  $listener.Start()
  try {
    return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
  } finally {
    $listener.Stop()
  }
}

function Measure-PngDiversity {
  param([Parameter(Mandatory = $true)][byte[]]$Bytes)
  Add-Type -AssemblyName System.Drawing
  $stream = [System.IO.MemoryStream]::new($Bytes)
  $bitmap = $null
  try {
    $bitmap = [System.Drawing.Bitmap]::FromStream($stream)
    $colors = [System.Collections.Generic.HashSet[int]]::new()
    $opaqueSamples = 0
    $stepX = [Math]::Max(1, [Math]::Floor($bitmap.Width / 60))
    $stepY = [Math]::Max(1, [Math]::Floor($bitmap.Height / 60))
    for ($y = 0; $y -lt $bitmap.Height; $y += $stepY) {
      for ($x = 0; $x -lt $bitmap.Width; $x += $stepX) {
        $color = $bitmap.GetPixel($x, $y)
        if ($color.A -ge 16) {
          $opaqueSamples += 1
          [void]$colors.Add($color.ToArgb())
        }
      }
    }
    return [pscustomobject]@{
      distinctOpaqueColors = $colors.Count
      opaqueSamples = $opaqueSamples
      width = $bitmap.Width
      height = $bitmap.Height
    }
  } finally {
    if ($bitmap) { $bitmap.Dispose() }
    $stream.Dispose()
  }
}

function Get-SafeDiagnosticUrl {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
  try {
    $uri = [uri]$Value
    return $uri.GetLeftPart([System.UriPartial]::Path)
  } catch {
    return ''
  }
}

function Send-WebSocketText {
  param(
    [Parameter(Mandatory = $true)]$Socket,
    [Parameter(Mandatory = $true)][string]$Text
  )
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $segment = [System.ArraySegment[byte]]::new($bytes, 0, $bytes.Length)
  $Socket.SendAsync(
    $segment,
    [System.Net.WebSockets.WebSocketMessageType]::Text,
    $true,
    [System.Threading.CancellationToken]::None
  ).GetAwaiter().GetResult()
}

function Receive-WebSocketJson {
  param(
    [Parameter(Mandatory = $true)]$Socket,
    [ValidateRange(1, 60)][int]$TimeoutSeconds = 30
  )
  $buffer = New-Object byte[] 65536
  $stream = [System.IO.MemoryStream]::new()
  $cancellation = [System.Threading.CancellationTokenSource]::new()
  $cancellation.CancelAfter([TimeSpan]::FromSeconds($TimeoutSeconds))
  try {
    do {
      $segment = [System.ArraySegment[byte]]::new(
        $buffer,
        0,
        $buffer.Length
      )
      $result = $Socket.ReceiveAsync(
        $segment,
        $cancellation.Token
      ).GetAwaiter().GetResult()
      if ($result.MessageType -eq
          [System.Net.WebSockets.WebSocketMessageType]::Close) {
        throw 'The browser debugging connection closed unexpectedly.'
      }
      $stream.Write($buffer, 0, $result.Count)
    } while (-not $result.EndOfMessage)
    $json = [System.Text.Encoding]::UTF8.GetString($stream.ToArray())
    return $json | ConvertFrom-Json
  } finally {
    $cancellation.Dispose()
    $stream.Dispose()
  }
}

$script:NextCommandId = 0
$script:BrowserErrors = [System.Collections.Generic.List[string]]::new()

function Add-BrowserEvent {
  param([Parameter(Mandatory = $true)]$Message)
  if ($Message.method -eq 'Runtime.exceptionThrown') {
    $details = $Message.params.exceptionDetails
    $description = if ($details.exception.description) {
      [string]$details.exception.description
    } else {
      [string]$details.text
    }
    if ($description) {
      $script:BrowserErrors.Add($description.Split("`n")[0])
    }
  }
  if ($Message.method -eq 'Log.entryAdded' -and
      $Message.params.entry.level -eq 'error') {
    $entry = $Message.params.entry
    $safeUrl = Get-SafeDiagnosticUrl -Value ([string]$entry.url)
    $description = [string]$entry.text
    if ($safeUrl) {
      $description = "$description [$safeUrl]"
    }
    $script:BrowserErrors.Add($description)
  }
  if ($Message.method -eq 'Runtime.consoleAPICalled' -and
      $Message.params.type -eq 'error') {
    $parts = @($Message.params.args | ForEach-Object {
      if ($null -ne $_.value) { [string]$_.value } else { [string]$_.description }
    })
    $script:BrowserErrors.Add(($parts -join ' '))
  }
}

function Invoke-CdpCommand {
  param(
    [Parameter(Mandatory = $true)]$Socket,
    [Parameter(Mandatory = $true)][string]$Method,
    [hashtable]$Parameters = @{}
  )
  $script:NextCommandId += 1
  $commandId = $script:NextCommandId
  Send-WebSocketText -Socket $Socket -Text (@{
    id = $commandId
    method = $Method
    params = $Parameters
  } | ConvertTo-Json -Compress -Depth 20)

  while ($true) {
    $message = Receive-WebSocketJson -Socket $Socket
    if ($message.id -eq $commandId) {
      if ($message.error) {
        throw "Browser command $Method failed: $($message.error.message)"
      }
      return $message.result
    }
    if ($message.method) {
      Add-BrowserEvent -Message $message
    }
  }
}

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$absoluteScreenshot = if ([System.IO.Path]::IsPathRooted($ScreenshotPath)) {
  [System.IO.Path]::GetFullPath($ScreenshotPath)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $workspace $ScreenshotPath))
}
$screenshotDirectory = Split-Path -Parent $absoluteScreenshot
New-Item -ItemType Directory -Force -Path $screenshotDirectory | Out-Null

$browserPath = Resolve-BrowserPath
$port = Get-FreeTcpPort
$profilePath = Join-Path (
  [System.IO.Path]::GetTempPath()
) "pipe-buyer-browser-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $profilePath | Out-Null

$browserProcess = $null
$socket = $null
try {
  $browserProcess = Start-Process -FilePath $browserPath -ArgumentList @(
    '--headless=new',
    '--enable-webgl',
    '--ignore-gpu-blocklist',
    '--use-angle=swiftshader',
    '--disable-extensions',
    '--no-first-run',
    '--no-default-browser-check',
    "--remote-debugging-port=$port",
    "--user-data-dir=$profilePath",
    'about:blank'
  ) -WindowStyle Hidden -PassThru

  $target = $null
  $connectDeadline = [DateTime]::UtcNow.AddSeconds(15)
  do {
    try {
      $targets = Invoke-RestMethod -Uri "http://127.0.0.1:$port/json/list"
      $target = @($targets | Where-Object { $_.type -eq 'page' }) |
        Select-Object -First 1
    } catch {
      Start-Sleep -Milliseconds 250
    }
  } while (-not $target -and [DateTime]::UtcNow -lt $connectDeadline)
  if (-not $target) {
    throw 'Could not connect to the headless browser.'
  }

  $socket = [System.Net.WebSockets.ClientWebSocket]::new()
  $socket.ConnectAsync(
    [uri]$target.webSocketDebuggerUrl,
    [System.Threading.CancellationToken]::None
  ).GetAwaiter().GetResult() | Out-Null

  Invoke-CdpCommand -Socket $socket -Method 'Runtime.enable' | Out-Null
  Invoke-CdpCommand -Socket $socket -Method 'Log.enable' | Out-Null
  Invoke-CdpCommand -Socket $socket -Method 'Page.enable' | Out-Null
  Invoke-CdpCommand -Socket $socket -Method 'Accessibility.enable' | Out-Null
  if (-not [string]::IsNullOrWhiteSpace($AppCheckDebugToken)) {
    $debugTokenLiteral = $AppCheckDebugToken | ConvertTo-Json -Compress
    Invoke-CdpCommand -Socket $socket `
      -Method 'Page.addScriptToEvaluateOnNewDocument' `
      -Parameters @{
        source = "self.FIREBASE_APPCHECK_DEBUG_TOKEN = $debugTokenLiteral;"
      } | Out-Null
  }
  Invoke-CdpCommand -Socket $socket -Method 'Emulation.setDeviceMetricsOverride' `
    -Parameters @{
      width = $ViewportWidth
      height = $ViewportHeight
      deviceScaleFactor = 1
      mobile = $true
      screenWidth = $ViewportWidth
      screenHeight = $ViewportHeight
    } | Out-Null
  Invoke-CdpCommand -Socket $socket -Method 'Page.navigate' `
    -Parameters @{ url = $Url } | Out-Null

  $pageStateExpression = @'
(() => {
  const roots = [
    document,
    document.querySelector('flutter-view')?.shadowRoot,
    document.querySelector('flt-glass-pane')?.shadowRoot
  ].filter(Boolean);
  const scene = roots.map((root) => root.querySelector('flt-scene-host'))
    .find(Boolean);
  const canvas = roots.map((root) => root.querySelector('canvas')).find(Boolean);
  const view = document.querySelector('flutter-view, flt-glass-pane');
  const viewRect = view?.getBoundingClientRect();
  const semantics = roots.flatMap((root) => [
    ...root.querySelectorAll('flt-semantics')
  ]);
  const accessibilityText = semantics.map((node) =>
    node.getAttribute('aria-label') || node.textContent || ''
  ).join(' ').replace(/\s+/g, ' ').trim().slice(0, 1000);
  return JSON.stringify({
    readyState: document.readyState,
    title: document.title,
    text: (document.body?.innerText || '').trim().slice(0, 500),
    accessibilityText,
    hasFlutterRoot: Boolean(view),
    hasFlutterScene: Boolean(scene),
    hasCanvas: Boolean(canvas),
    canvasWidth: canvas?.width || 0,
    canvasHeight: canvas?.height || 0,
    canvasDataLength: (() => {
      try { return canvas?.toDataURL('image/png').length || 0; }
      catch (_) { return 0; }
    })(),
    renderedNodeCount: scene?.querySelectorAll('*').length || 0,
    sceneHtmlLength: scene?.innerHTML.length || 0,
    viewWidth: Math.round(viewRect?.width || 0),
    viewHeight: Math.round(viewRect?.height || 0),
    bodyChildren: document.body?.children.length || 0,
    bootstrapPresent: Boolean(document.getElementById('splash')),
    width: window.innerWidth,
    height: window.innerHeight
  });
})()
'@
  $pageState = $null
  $renderDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  do {
    Start-Sleep -Milliseconds 500
    $evaluation = Invoke-CdpCommand -Socket $socket -Method 'Runtime.evaluate' `
      -Parameters @{
        expression = $pageStateExpression
        returnByValue = $true
      }
    if ($evaluation.result.value) {
      $pageState = $evaluation.result.value | ConvertFrom-Json
    }
  } while (
    $pageState.renderedNodeCount -lt 10 -and
    $pageState.canvasDataLength -lt 5000 -and
    -not $pageState.text -and
    [DateTime]::UtcNow -lt $renderDeadline
  )

  # Flutter's router intentionally retains its branded splash for three
  # seconds. Enable its accessibility tree and capture the usable page after
  # that transition, not the splash.
  Invoke-CdpCommand -Socket $socket -Method 'Runtime.evaluate' `
    -Parameters @{
      expression = @'
(() => {
  const queue = [document];
  let placeholder = null;
  while (queue.length && !placeholder) {
    const root = queue.shift();
    placeholder = root.querySelector?.(
      'flt-semantics-placeholder,[aria-label="Enable accessibility"]'
    ) || null;
    for (const element of root.querySelectorAll?.('*') || []) {
      if (element.shadowRoot) queue.push(element.shadowRoot);
    }
  }
  if (!placeholder) return false;
  placeholder.click();
  return true;
})()
'@
      returnByValue = $true
    } | Out-Null
  Start-Sleep -Seconds $StabilizationSeconds
  $finalEvaluation = Invoke-CdpCommand -Socket $socket -Method 'Runtime.evaluate' `
    -Parameters @{
      expression = $pageStateExpression
      returnByValue = $true
    }
  if ($finalEvaluation.result.value) {
    $pageState = $finalEvaluation.result.value | ConvertFrom-Json
  }
  $accessibilityTree = Invoke-CdpCommand -Socket $socket `
    -Method 'Accessibility.getFullAXTree'
  $accessibilityTreeText = @(
    $accessibilityTree.nodes |
      Where-Object { -not $_.ignored -and $_.name.value } |
      ForEach-Object { [string]$_.name.value }
  ) -join ' '

  $capture = Invoke-CdpCommand -Socket $socket -Method 'Page.captureScreenshot' `
    -Parameters @{
      format = 'png'
      fromSurface = $true
      captureBeyondViewport = $false
    }
  $pageBytes = [Convert]::FromBase64String($capture.data)
  $pageDiversity = Measure-PngDiversity -Bytes $pageBytes
  $selectedBytes = $pageBytes
  $selectedDiversity = $pageDiversity
  $captureSource = 'page'

  $canvasCapture = Invoke-CdpCommand -Socket $socket -Method 'Runtime.evaluate' `
    -Parameters @{
      expression = @'
(() => {
  const roots = [
    document,
    document.querySelector('flutter-view')?.shadowRoot,
    document.querySelector('flt-glass-pane')?.shadowRoot
  ].filter(Boolean);
  const canvas = roots.map((root) => root.querySelector('canvas')).find(Boolean);
  if (!canvas) return '';
  try { return canvas.toDataURL('image/png'); }
  catch (_) { return ''; }
})()
'@
      returnByValue = $true
    }
  $canvasDataUrl = [string]$canvasCapture.result.value
  if ($canvasDataUrl.StartsWith('data:image/png;base64,') -and
      $canvasDataUrl.Length -ge 5000) {
    $canvasBytes = [Convert]::FromBase64String(
      $canvasDataUrl.Substring('data:image/png;base64,'.Length)
    )
    $canvasDiversity = Measure-PngDiversity -Bytes $canvasBytes
    if ($canvasDiversity.distinctOpaqueColors -gt
        $selectedDiversity.distinctOpaqueColors) {
      $selectedBytes = $canvasBytes
      $selectedDiversity = $canvasDiversity
      $captureSource = 'canvas'
    }
  }
  [System.IO.File]::WriteAllBytes($absoluteScreenshot, $selectedBytes)

  $uniqueErrors = @($script:BrowserErrors | Where-Object { $_ } | Select-Object -Unique)
  $hasRenderedContent = [int]$pageState.renderedNodeCount -ge 10 -or
    [int]$pageState.canvasDataLength -ge 5000 -or
    [bool]$pageState.text
  $hasTrustworthyPixels = $selectedDiversity.opaqueSamples -gt 0 -and
    $selectedDiversity.distinctOpaqueColors -ge 3
  $combinedText = (
    "$($pageState.text) $($pageState.accessibilityText) $accessibilityTreeText"
  ).Trim()
  $hasExpectedText = [string]::IsNullOrWhiteSpace($ExpectedTextPattern) -or
    $combinedText -match $ExpectedTextPattern
  $result = [ordered]@{
    url = $Url
    readyState = $pageState.readyState
    title = $pageState.title
    hasFlutterRoot = [bool]$pageState.hasFlutterRoot
    hasFlutterScene = [bool]$pageState.hasFlutterScene
    hasCanvas = [bool]$pageState.hasCanvas
    canvasSize = "$($pageState.canvasWidth)x$($pageState.canvasHeight)"
    canvasDataLength = [int]$pageState.canvasDataLength
    renderedNodeCount = [int]$pageState.renderedNodeCount
    sceneHtmlLength = [int]$pageState.sceneHtmlLength
    viewSize = "$($pageState.viewWidth)x$($pageState.viewHeight)"
    bodyChildren = [int]$pageState.bodyChildren
    bootstrapPresent = [bool]$pageState.bootstrapPresent
    viewport = "$($pageState.width)x$($pageState.height)"
    visibleText = [string]$pageState.text
    accessibilityText = [string]$pageState.accessibilityText
    accessibilityTreeText = $accessibilityTreeText
    expectedTextPattern = $ExpectedTextPattern
    hasExpectedText = $hasExpectedText
    browserErrors = $uniqueErrors
    captureSource = $captureSource
    distinctOpaqueColors = [int]$selectedDiversity.distinctOpaqueColors
    opaqueSamples = [int]$selectedDiversity.opaqueSamples
    screenshot = $absoluteScreenshot
    passed = $hasRenderedContent -and
      $hasTrustworthyPixels -and
      -not [bool]$pageState.bootstrapPresent -and
      $hasExpectedText -and
      $uniqueErrors.Count -eq 0
  }
  $result | ConvertTo-Json -Depth 8
  if (-not $result.passed) {
    throw 'Web visual smoke test failed. See the structured result above.'
  }
} finally {
  if ($socket) {
    $socket.Dispose()
  }
  if ($browserProcess -and -not $browserProcess.HasExited) {
    Stop-Process -Id $browserProcess.Id -Force -ErrorAction SilentlyContinue
  }
  $resolvedTemp = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()
  )
  $resolvedProfile = [System.IO.Path]::GetFullPath($profilePath)
  if ($resolvedProfile.StartsWith(
      (Join-Path $resolvedTemp 'pipe-buyer-browser-'),
      [System.StringComparison]::OrdinalIgnoreCase
    )) {
    for ($attempt = 0; $attempt -lt 8; $attempt += 1) {
      if (-not (Test-Path -LiteralPath $resolvedProfile)) { break }
      Start-Sleep -Milliseconds 250
      Remove-Item -LiteralPath $resolvedProfile -Recurse -Force `
        -ErrorAction SilentlyContinue
    }
  }
}
