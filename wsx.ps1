#powershell -File

[cmdletBinding(SupportsShouldProcess=$false, ConfirmImpact='Medium')]
param($HTTPEndPoint = 'http://localhost:8082/', $LocalRoot = './view/')

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

#The old approach is obsolete, a local approach adds security
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

  # Get the file extension from the filename
  $extension = [IO.Path]::GetExtension($filename)

  # Look up the MIME type for the file extension in the hash table
  return $mimeTypeMap[$extension]
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

  $binaryMimeTypes = @(
    "image/png"
    "image/jpeg"
    "image/gif"
    "application/pdf"
  )

  try {
    $mimeType = Get-MimeType($path)
    if($mimeType -eq $null){
      Get-HTTPStringResponse -Response $response -string "Unsupported MIME type"
      return
    }
    
    # Generate Response
    if ($binaryMimeTypes -contains $mimeType) {
      if ($PSMajorVersion -gt 5) {
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
  }
  catch [System.Exception] {
    Write-Verbose "ERROR: $($_)"
    return ""
  }
}

function Kill-Server {
  Write-Verbose "Stopping server...";
  $listener.Close(); 
  if($reponse -ne $null){
    $response.StatusCode = 200; 
    $response.Close();
  }
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add( $HTTPEndPoint )
$listener.Start()
Write-Verbose "Listening at $HTTPEndPoint..."

Register-ObjectEvent -InputObject $host -EventName PowerShellExit -Action { Kill-Server }  

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
    if ($localPath.startsWith("/xls/")){
      Write-Verbose "Excel request detected"
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