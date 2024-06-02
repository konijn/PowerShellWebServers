# PowerShellWebServers

Simple powershell web server. Inspired by https://github.com/ChristopherGLewis/PowerShellWebServers

## Powershell-WebServer.ps1
This takes the HTTPListener to the extreme, and creates a moderately functioning web server.  

You pass a URL to listen on, and a path that's your root (has to end in a '\\'), 
and the script servers up http content.

It's not threaded, and currently doesn't handle mime types other then text, but that could be handled in the `Get-HTTPResponse` function.     

Kept as reference implementation

## WS.ps1

A clone of the previous shell.
Defaulted hosting folder as ./view
