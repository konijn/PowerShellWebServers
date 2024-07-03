#powershell -File 

[cmdletBinding(ConfirmImpact='Low')]
param($HTTPEndPoint = 'http://localhost:8080/', $LocalRoot = './view/')

Set-StrictMode -Version latest

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

#The old approach is obsolete, plus a local approach adds some security
function Get-MimeType {
  param ([string]$filename)

  $mimeTypeMap = @{
    '.txt' = 'text/plain';
    '.html' = 'text/html';
    '.css' = 'text/css';
    '.js' = 'application/javascript';
    '.json' = 'application/json';
    '.xml' = 'application/xml';
    '.png' = 'image/png';
    '.jpg' = 'image/jpeg';
    '.gif' = 'image/gif';
    '.pdf' = 'application/pdf';
    '.webmanifest' = 'application/manifest+json';
  }
  # Look up the MIME type for the file extension in the hash table
  return $mimeTypeMap[ [IO.Path]::GetExtension($filename) ]
}

function Get-HTTPStringResponse {
  param ($response, $string)  
  # Generate Response from the provided string
  $buffer = [System.Text.Encoding]::UTF8.GetBytes($string)
  $response.ContentLength64 = $buffer.Length
  $response.ContentType = 'text/plain'
  $response.OutputStream.Write($buffer, 0, $buffer.Length)       
}

function Get-HTTPResponse {  
  param($response, $path)

  $binaryMimeTypes = @(
    "image/png"
    "image/jpeg"
    "image/gif"
    "application/pdf"
  )

  try {
    $mimeType = Get-MimeType($path)
    if ( $mimeType -eq $null ) {
      Get-HTTPStringResponse -Response $response -string "Unsupported MIME type"
      return
    }
    
    # Handle binary files different from text files, binary handling is different for 6+
    if ( $binaryMimeTypes -contains $mimeType ) {
      if ( $PSVersionTable.PSVersion -gt 5 ) {
        $content = ( Get-Content -Path $path -AsByteStream -Raw )        
      } else {
        $content = ( Get-Content -Path $path -Encoding Byte -Raw )        
      }      
    } else {
      $content = ( Get-Content -Path $path -Raw )  
      $content = [System.Text.Encoding]::UTF8.GetBytes($content)
    }
    
    $response.ContentType = $mimeType    
    $response.ContentLength64 = $content.Length
    $response.OutputStream.Write($content, 0, $content.Length)   
  } catch [System.Exception] {
    Write-Verbose "ERROR: $($_)"
  }
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add( $HTTPEndPoint )
$listener.Start()
Write-Verbose "Listening at $HTTPEndPoint..."
Write-Verbose "To stop, visit $HTTPEndPoint/kill or press Control Break, and then type quit<enter>"

try{
  while ($listener.IsListening){

    $contextTask = $listener.GetContextAsync()
    while (-not $contextTask.AsyncWaitHandle.WaitOne(200)){}
    $context = $contextTask.GetAwaiter().GetResult()

    $requestUrl = $context.Request.Url
    $response = $context.Response
    $method = $context.Request.HttpMethod 
  
    try {    
      $localPath = $requestUrl.LocalPath
      if ( $localPath -eq "/" ) { $localPath = "/index.html" }
      if ( $localPath -eq '/kill' ) { break } #kill server
      $FullPath = join-path -Path $LocalRoot -ChildPath $LocalPath
      if ( Test-Path $FullPath ) {
        Write-Verbose "Querying $requestUrl"
        Get-HTTPResponse -response $response -path  $FullPath         
      } else {
		$response.StatusCode = 404  
        Write-Verbose "$response.StatusCode $requestUrl"
      }
    } catch {
      $response.StatusCode = 500
	  Write-Verbose "$response.StatusCode $requestUrl"
	  Write-Verbose "ERROR: $($_)"
    }
    $response.Close()
  }
} catch {
  Write-Verbose "ERROR: $($_)"    
}
finally {
  Write-Verbose "Stopping server..."
  $listener.Stop()
  $listener.Close()
  $listener.Dispose()
}
