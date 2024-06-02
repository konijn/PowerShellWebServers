###
##
# Minimal CMS
##
###

[cmdletBinding(SupportsShouldProcess=$false, ConfirmImpact='Medium')]
param($HTTPEndPoint = 'http://localhost:8081/', $LocalRoot = './view/')

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

#The old approach is obsolete, the new approach counts on nuget
#So I would rather have this contained in here, if the filetype
#is not in here, it wont be served (security..)
function Get-MimeType {
  param ([string]$filename)

  # Define a hash table to map file extensions to MIME types
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

  # Get the file extension from the filename
  $extension = [IO.Path]::GetExtension($filename)

  # Look up the MIME type for the file extension in the hash table
  if ($mimeTypeMap.ContainsKey($extension)) {
    return $mimeTypeMap[$extension]
  } else {
    Write-Verbose "Unknown file extension: $extension"
  }
}

function Get-HTTPStringResponse {
  param ($response, $string)  
  # Generate Response from the provided string
  $buffer = [System.Text.Encoding]::UTF8.GetBytes($string)
  $response.ContentLength64 = $buffer.Length
  $response.ContentType = 'text/plain'
  $response.OutputStream.Write($buffer, 0, $buffer.Length)       
}

function Get-HTTPResponse  {  
  param($response, $path)

  try {
    $mimeType = Get-MimeType($path)
    if($mimeType -eq $null){
      Get-HTTPStringResponse -Response $response -string "Unsupported MIME type"
      return
    }
    
    # Generate Response
    $content = ( Get-Content -Path $path -Raw )  
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
    
    $length = $buffer.Length
    Write-Verbose "Length: $length"
    
    $response.ContentLength64 = $buffer.Length
    $response.ContentType = $mimeType
    $response.OutputStream.Write($buffer, 0, $buffer.Length)   
  }
  catch [System.Exception] {
    Write-Verbose "ERROR: $($_)"
    return ""
  }
}

function Kill-Server {
  param($response, $listener)
  Write-Verbose "Stopping server...";
  $response.StatusCode = 200; 
  $response.Close();
  $listener.Close(); 
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add( $HTTPEndPoint )
$listener.Start()
Write-Verbose "Listening at $HTTPEndPoint..."

while ($listener.IsListening) {
  $context = $listener.GetContext()
  $requestUrl = $context.Request.Url
  $response = $context.Response
  $method = $context.Request.HttpMethod 

  try {    
    $localPath = $requestUrl.LocalPath
    #Close server
    if ($localPath -eq '/kill') {
      Kill-Server -response $response -listener $listener
      break; 
    }
    $FullPath = join-path -Path $LocalRoot -ChildPath $LocalPath
    if ( Test-Path $FullPath )  {
      Write-Verbose "Querying $requestUrl"
      Get-HTTPResponse -response $response -path  $FullPath         
    } else {
      Write-Verbose "404 $requestUrl"
      $response.StatusCode = 404
    }
  } catch {
    $response.StatusCode = 500
  }
  $response.Close()
}