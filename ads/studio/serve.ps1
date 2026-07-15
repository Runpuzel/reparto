param(
  [int]$Port = 8765,
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()

$mime = @{
  '.html' = 'text/html; charset=utf-8'
  '.js'   = 'text/javascript; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.png'  = 'image/png'
  '.webp' = 'image/webp'
  '.svg'  = 'image/svg+xml'
}

try {
  while ($listener.IsListening) {
    $context = $null
    try {
    $context = $listener.GetContext()
    if ($context.Request.HttpMethod -eq 'POST' -and
        $context.Request.Url.AbsolutePath -eq '/upload') {
      $name = [System.IO.Path]::GetFileName($context.Request.QueryString['name'])
      if ($name -notmatch '^[a-z0-9-]+\.(mp4|webm)$') {
        $context.Response.StatusCode = 400
        $context.Response.Close()
        continue
      }
      $output = Join-Path $Root 'ads\output'
      [System.IO.Directory]::CreateDirectory($output) | Out-Null
      $destination = Join-Path $output $name
      $stream = [System.IO.File]::Create($destination)
      try {
        $context.Request.InputStream.CopyTo($stream)
      } finally {
        $stream.Close()
      }
      $reply = [Text.Encoding]::UTF8.GetBytes('{"saved":true}')
      $context.Response.ContentType = 'application/json'
      $context.Response.ContentLength64 = $reply.Length
      $context.Response.OutputStream.Write($reply, 0, $reply.Length)
      $context.Response.Close()
      continue
    }
    $relative = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
    if ([string]::IsNullOrWhiteSpace($relative)) {
      $relative = 'ads/studio/ujustbuy_ad_studio.html'
    }
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $Root $relative))
    if (-not $candidate.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
      $context.Response.StatusCode = 404
      $context.Response.Close()
      continue
    }
    $bytes = [System.IO.File]::ReadAllBytes($candidate)
    $extension = [System.IO.Path]::GetExtension($candidate).ToLowerInvariant()
    $context.Response.ContentType = if ($mime.ContainsKey($extension)) { $mime[$extension] } else { 'application/octet-stream' }
    $context.Response.ContentLength64 = $bytes.Length
    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $context.Response.Close()
    } catch {
      if ($null -ne $context) {
        try { $context.Response.Abort() } catch { }
      }
    }
  }
} finally {
  $listener.Stop()
  $listener.Close()
}
