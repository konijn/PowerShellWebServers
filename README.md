# PowerShellWebServers

Simple powershell web server. Inspired by https://github.com/ChristopherGLewis/PowerShellWebServers

## Powershell-WebServer.ps1
This takes the HTTPListener to the extreme, and creates a moderately functioning web server.  

You pass a URL to listen on, and a path that's your root (has to end in a '\\'), 
and the script servers up http content.

It's not threaded, and currently doesn't handle mime types other then text, but that could be handled in the `Get-HTTPResponse` function.     

Kept as reference implementation

## ws.ps1

Changes to Powershell-WebServer.ps1
* A clone of the previous shell.
* Defaulted hosting folder as ./view
* Increased impact to Medium
* Local MIME mapping, blocks unknown MIME calls
* Differentiate between text and binary responses
* Dumb down parameters for easier reading / cutting lines
* Support binary mime types (PowerShell 5.1 and 6+)
* You can kill now by pressing control C
* Added support for PS7+


## wsx.ps1

Cloned from WS.ps1
* REST services to access Excel files
  * Workbooks list 
  * Worksheets list
  * Worksheet content
* Internal consistency checks added
