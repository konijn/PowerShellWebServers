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
    '.api.html' = 'text/html';
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
  param ($response, $string, $mime = 'text/plain')  
  # Generate Response from the provided string
  $buffer = [System.Text.Encoding]::UTF8.GetBytes($string)
  $response.ContentLength64 = $buffer.Length
  $response.ContentType = $mime
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
      if ( $PSVersionTable.PSVersion.Major -gt 5 ) {
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

# Function to open or get the workbook handle
function Get-WorkbookHandle {
    param (
        [string]$BaseName
    )
    # Check if the workbook is already opened and in the dictionary
    if ($workbooks.ContainsKey($BaseName)) {
        # Return the existing workbook handle
        return $workbooks[$BaseName]
    } else {
        # Open the workbook and add it to the dictionary
        $danger = Get-Location
        $path = join-path -Path $danger -ChildPath "/xls/$($BaseName).xlsx"
        Write-Verbose "Loading $path"  
        #$workbook = $global:excel.Workbooks.Open($path)
        $workbook = $excel.Workbooks.Open($path)
        #Write-Verbose $workbook | ConvertTo-Json 
        $workbooks[$BaseName] = $workbook

        # Return the new workbook handle
        return $workbook
    }
}

function Route-Rest {  
  param($method, $htmlRequested, $response, $path)
  Write-Verbose 'Doing the API'
  
  $stream = $response.OutputStream
  
  $path = $path.trimStart("/xls/api/")
  
  $sections = $path -split '/'
  $sectionsCount = $sections.Count
  Write-Verbose "html $htmlRequested Path $path Section count $sectionsCount"
  
  # Provide the list of workbooks
  if(($sectionsCount -eq 1) -and ($sections[0] -eq "")){
    if( $htmlRequested -eq $true){
      Get-HTTPResponse -response $response -path  "view/xls/xls.api.html"  
    } else {
      $files = (dir ./xls/*.xlsx) | Select-Object -Property BaseName
      foreach($file in $files){
        $file | Add-Member -MemberType NoteProperty -Name uri -Value "/xls/api/$($file.BaseName)"
        $file | Add-Member -MemberType NoteProperty -Name loaded -Value $workbooks.ContainsKey($file.BaseName)
      }
      $json =  $files | ConvertTo-Json 
      Get-HTTPStringResponse -Response $response -string $json -mime 'application/json'
    }
  }
  
  # Provide the list of worksheets 
  if(($sectionsCount -eq 1) -and ($sections[0] -ne "")){
    if( $htmlRequested -eq $true){
      Get-HTTPResponse -response $response -path  "view/xls/xls.api-wb.html"  
    } else { 
      $workbook = Get-WorkbookHandle -BaseName $sections[0]
      $list = $workbook.Worksheets | Where-Object { $_.Visible -eq -1 } | Select-Object -Property Name
      foreach($ws in $list){
        $ws | Add-Member -MemberType NoteProperty -Name uri -Value "/xls/api/$($sections[0])/$($ws.Name)"
      }
      $json =  $list | ConvertTo-Json 
      Get-HTTPStringResponse -Response $response -string $json -mime 'application/json'      
    }
  }

  # GET Provide the data of a worksheet (all of it)
  # PUT  updating existing line(s)
  # POST add new line(s)
  
  if($sectionsCount -eq 2){
    $fields = @()
    $lines = @()
    if( $htmlRequested -eq $true){
      Get-HTTPResponse -response $response -path  "view/xls/xls.api-ws.html"  
    } else { 
      $workbook = Get-WorkbookHandle -BaseName $sections[0]
      $worksheet = $workbook.Sheets.Item($sections[1])
        
      $usedRange = $worksheet.UsedRange
      $rows = $usedRange.Rows.Count
      $columns = $usedRange.Columns.Count
	  
      if( $columns -eq 0 ){
        $fields = @("Error");
        $lines = @(@("No columns are defined in this Worksheet"))
      } else {
        $fields = @()
        $dataRange = $worksheet.Range("A1", $worksheet.Cells.Item(1, $columns))
        for ($col = 1; $col -le $columns; $col++) {
          $fields += $worksheet.Cells.Item(1, $col).Text
        }
        
        if($rows -gt 1 ){
          for ($row = 2; $row -le $rows; $row++) {
            $line = @()
            for ($col = 1; $col -le $columns; $col++) {
              $value = $worksheet.Cells.Item($row, $col).Text
              $line += $value
            }
            $lines += ,$line
          }   
        }
      }
      $data = [PSCustomObject]@{
        fields = $fields
        values = $lines
      }
      $json =  $data | ConvertTo-Json 
      Write-Verbose $json
      Get-HTTPStringResponse -Response $response -string $json -mime 'application/json'            
		}
  }
}

#Perform sanity checks
if (!(Test-Path -Path 'view' -PathType Container)) {
  Write-Verbose "This script expects a folder called 'view'"
  exit
}
if (!(Test-Path -Path 'xls' -PathType Container)) {
  Write-Verbose "This script expects a folder called 'xls'"
  exit
}

#Set up Excel COM object and handles
$excel = New-Object -ComObject Excel.Application -Verbose:$false
$excel.Visible = $false
$workbooks = @{}

#Set up HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add( $HTTPEndPoint )
$listener.Start()
Write-Verbose "Listening at $HTTPEndPoint..."
Write-Verbose "To stop this you have options:"
Write-Verbose "1. Visit $HTTPEndPoint/kill"
Write-Verbose "2. Press Control-C"
Write-Verbose "3. Press Control Break, and then type quit<enter>"

try{
  while ($listener.IsListening){

    $contextTask = $listener.GetContextAsync()
    while (-not $contextTask.AsyncWaitHandle.WaitOne(200)){}
    $context = $contextTask.GetAwaiter().GetResult()

    $requestUrl = $context.Request.Url
    $response = $context.Response
    $method = $context.Request.HttpMethod
    $htmlRequested = ($context.Request.AcceptTypes -Contains 'text/html')

  
    try {    
      $localPath = $requestUrl.LocalPath
      Write-Verbose $localPath
      $localPath = $localPath.TrimEnd("/")
      if ( $localPath -eq "" ) { 
        $localPath = "/index.html" 
      } ElseIf ( $localPath -eq '/kill' ) { 
        break 
      }
      If ( $localPath.StartsWith('/xls/api') ){
        Route-Rest -method $method -htmlRequested $htmlRequested -response $response -Path $localPath
      } else {
        $FullPath = join-path -Path $LocalRoot -ChildPath $LocalPath
        if ( Test-Path $FullPath ) {
          #Write-Verbose "Querying $requestUrl"
          Get-HTTPResponse -response $response -path  $FullPath         
        } else {
          $response.StatusCode = 404  
          Write-Verbose "$($response.StatusCode) $requestUrl"
        }
      }
    } catch {
      $response.StatusCode = 500
      Write-Verbose "$($response.StatusCode) $requestUrl"
      Write-Verbose "ERROR: $($_)"
      Write-Host $_.ScriptStackTrace
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
  Write-Verbose "Stopping Excel..."
  # Quit the Excel application
  $excel.Quit()
  # Release COM objects
  foreach($workbook in $workbooks){
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
  }
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
}