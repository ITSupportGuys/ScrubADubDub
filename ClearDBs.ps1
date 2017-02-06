Get-ChildItem .\DB | ForEach-Object{
"{}" | Out-File .\DB\$_
}



