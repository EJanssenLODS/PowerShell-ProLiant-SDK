﻿########################################################
#Configure PCI Device on Gen10 servers
###################################################----#

<#
.Synopsis
    This Script allows user to configure PCI device for HPE Proliant Gen10 servers

.DESCRIPTION
    This script allows user to configure PCI device.Following features can be configured. This script works for single server at a time.
    PCIDeviceEnable/PCIDeviceDisable
    PCIeLinkSpeed
    
.EXAMPLE
    ConfigurePCIDeviceWithPCIeLinkSpeedForGen10.ps1

    This mode of execution of script will prompt for 
   
    -Address    :- Accept IP(s) or Hostname(s). For multiple servers IP(s) or Hostname(s) should be separated by comma(,)
   
    -Credential :- it will prompt for user name and password. In case multiple server IP(s) or Hostname(s) it is recommended to use same user credentials
   
    -PCIDevice   :- Accepted values are listed under enum [HPE.BIOS.PCIDeviceForGen10].
   
    -PCIeLinkSpeed :- Accepted values are listed under enum [HPE.BIOS.PCIeLinkSpeed].
      

.EXAMPLE
    ConfigurePCIDeviceWithPCIeLinkSpeedForGen10.ps1 -Address "10.20.30.40" -Credential $userCredential -PCIDevice @(,@("EmbeddedNIC","EmbeddedSAS1")) -PCIeLinkSpeed @(,@("Auto")) -EnablePCIDevice

    This mode of script have input parameter for Address, Credential, PCIDevice, PCIeLinkSpeed, EnablPCIDevice, and DisablePCIDevice.
   
    -Address:- Use this parameter to specify  IP(s) or Hostname(s) of the server.
   
    -Credential :- Use this parameter to specify user Credential.
   
    -PCIDevice :- Use this Parameter to specify PCIDevice.
   
    -PCIeLinkSpeed : - This parameter to specify PCIeLinkSpeed.
   
    -EnablPCIDevice :- Switch parameter to enable PCI device.
   
    -DisablePCIDevice :- Switch parameter to disable PCI device.
    

.NOTES
    
    Company : Hewlett Packard Enterprise
    Version : 2.1.0.0
    Date    : 21/07/2017
    
.INPUTS
    Inputs to this script file
    Address
    Credential
    PCIDevice
    PCIeLinkSpeed
    

.OUTPUTS
    None (by default)

.LINK
    
    http://www.hpe.com/servers/powershell
    https://github.com/HewlettPackard/PowerShell-ProLiant-SDK/tree/master/HPEBIOS
#>



#Command line parameters
Param(
    [string]$Address,   # IP(s) or Hostname(s),
    [PSCredential]$Credential, # credential for server
    [String[]]$PCIDevice,
    [String[]]$PCIeLinkSpeed,
    [Switch]$EnablePCIDevice,
    [Switch]$DisablePCIDevice
    )

 #Check for server avaibiality

 function CheckServerAvailability ($ListOfAddress)
 {
    [int]$pingFailureCount = 0
    [array]$PingedServerList = @()
    foreach($serverAddress in $ListOfAddress)
    {
       if(Test-Connection $serverAddress)
       {
        #Write-Host "Server $serverAddress pinged successfully."
        $PingedServerList += $serverAddress
       }
       else
       {
        Write-Host ""
        Write-Host "Server $serverAddress is not reachable. Please check network connectivity"
        $pingFailureCount ++
       }
    }

    if($pingFailureCount -eq $ListOfAddress.Count)
    {
        Write-Host ""
        Write-Host "Server(s) are not reachable please check network conectivity"
        exit
    }
    return $PingedServerList
 }

#clear host
Clear-Host

# script execution started
Write-Host "****** Script execution started ******" -ForegroundColor Yellow
Write-Host ""
#Decribe what script does to the user

Write-Host "This script allows user to configure PCI Device on one target server.Following features can be configured."
Write-Host "Enabled and Disabled the PCI device"
Write-Host "Configure the PCIeLinkSpeed for the input PCIDevice"
Write-Host ""
Write-Host "This script works for single server at a time." -ForegroundColor Yellow

#dont shoe error in scrip

#$ErrorActionPreference = "Stop"
#$ErrorActionPreference = "Continue"
#$ErrorActionPreference = "Inquire"
$ErrorActionPreference = "SilentlyContinue"

#check powershell support
$PowerShellVersion = $PSVersionTable.PSVersion.Major

if($PowerShellVersion -ge "3")
{
    Write-Host "Your powershell version : $($PSVersionTable.PSVersion) is valid to execute this script"
    Write-Host ""
}
else
{
    Write-Host "This script required PowerSehll 3 or above"
    Write-Host "Current installed PowerShell version is $($PSVersionTable.PSVersion)"
    Write-Host "Please Update PowerShell version"
    Write-Host ""
    Write-Host "Exit..."
    Write-Host ""
    exit
}

#Load HPEBIOSCmdlets module
$InstalledModule = Get-Module
$ModuleNames = $InstalledModule.Name

if(-not($ModuleNames -like "HPEBIOSCmdlets"))
{
    Write-Host "Loading module :  HPEBIOSCmdlets"
    Import-Module HPEBIOSCmdlets
    if(($(Get-Module -Name "HPEBIOSCmdlets")  -eq $null))
    {
        Write-Host ""
        Write-Host "HPEBIOSCmdlets module cannot be loaded. Please fix the problem and try again"
        Write-Host ""
        Write-Host "Exit..."
        exit
    }
}
else
{
    $InstalledBiosModule  =  Get-Module -Name "HPEBIOSCmdlets"
    Write-Host "HPEBIOSCmdlets Module Version : $($InstalledBiosModule.Version) is installed on your machine."
    Write-host ""
}

# check for IP(s) or Hostname(s) Input. if not available prompt for Input

if($Address -eq "")
{
    $tempAddress = Read-Host "Enter single Server address (IP or Hostname)."

    if($tempAddress -ne "")
    {
        $Address = $tempAddress.Split(',')
    }
    else{
        Write-Host "You have not entered IP(s) or Hostname(s)"
        Write-Host "`nExit ..."
        exit
    }

}
    

if($Credential -eq $null)
{
    $Credential = Get-Credential -Message "Enter username and Password"
    Write-Host ""
}

#Ping and test IP(s) or Hostname(s) are reachable or not
$ListOfAddress =  CheckServerAvailability($Address)

#Create connection object
[array]$ListOfConnection = @()
$connection = $null
[int] $connectionCount = 0

foreach($IPAddress in $ListOfAddress)
{
    
    Write-Host ""
    Write-Host "Connecting to server  : $IPAddress"
    $connection = Connect-HPEBIOS -IP $IPAddress -Credential $Credential
    
     #Retry connection if it is failed because  of invalid certificate with -DisableCertificateAuthentication switch parameter
    if($Error[0] -match "The underlying connection was closed")
    {
       $connection = Connect-HPEBIOS -IP $IPAddress -Credential $Credential -DisableCertificateAuthentication
    } 

    if($connection -ne $null)
     {  
        Write-Host ""
        Write-Host "Connection established to the server $IPAddress" -ForegroundColor Green
        $connection
        if($connection.ProductName.Contains("Gen10"))
        {
            $ListOfConnection += $connection
        }
        else
        {
            Write-Host "Get/Set-HPEBIOSPCIDeviceConfiguration  is not supported on server $($connection.IP)"
			Disconnect-HPEBIOS -Connection $connection
        }
    }
    else
    {
         Write-Host "Connection cannot be eastablished to the server : $IPAddress" -ForegroundColor Red
    }
}

if($ListOfConnection.Count -eq 0)
{
    Write-Host "`nExit"
    exit
}

# Get current PCIDeviceConfiguration

Write-Host "`nCurrent PCI Device Configuration" -ForegroundColor Green
Write-Host ""
$counter = 1
foreach($serverConnection in $ListOfConnection)
{
        $getResult = $serverConnection | Get-HPEBIOSPCIDeviceConfiguration
        
        Write-Host "-------------------Server $($getResult.IP) -------------------" -ForegroundColor Yellow
        Write-Host ""
        $getResult.PCIDevice
        $CurrentPCIDeviceConfiguration += $getResult
        $counter++
}


# Get the valid value list fro each parameter
$workloadProfileParameterMetaData = $(Get-Command -Name Set-HPEBIOSWorkloadProfile).Parameters
$workloadProfileValidValues = $($workloadProfileParameterMetaData["WorkloadProfile"].Attributes | where {$_.TypeId.Name -eq "ValidateSetAttribute"}).ValidValues


#Prompt for User input if it is not given as script  parameter 
Write-Host "Input Hint : For multiple server please enter parameter values seprated by comma(,)" -ForegroundColor Yellow
Write-HOst ""

$PCIDeviceValidValues = [System.Enum]::GetNames([HPE.BIOS.PCIDeviceForGen10])
$PCIeLInkSpeedValidValues = [System.Enum]::GetNames([HPE.BIOS.PCIeLinkSpeed])

if($PCIDevice.Count -eq 0)
{
    $tempPCIDevice = Read-Host "Enter PCI device name [Accepted values : $($getResult.PCIDevice.Name -join ",")] "
    Write-Host ""
    if($tempPCIDevice -ne "")
    {
        $PCIDevice = $tempPCIDevice.Split(',')
    }
    else{
        Write-Host "No PCI device is provided"
        Write-Host "Exit....."
        exit
    }
}

if($PCIeLinkSpeed.Count -eq 0)
{
    $tempPCIeLinkSpeed = Read-Host "Enter PCIe link speed [Accepted values : $($PCIeLInkSpeedValidValues -join ",")]"
    Write-Host ""
    if($tempPCIeLinkSpeed -ne "")
    {
        $PCIeLinkSpeed = $tempPCIeLinkSpeed.Split(',')
    }
}


for($i = 0 ; $i -lt $PCIDevice.Count ;$i++)
{
    
    #validate user input PCIDevice
    if($($PCIDeviceValidValues | where{$_ -eq $PCIDevice[$i] }) -eq $null)
    {
        Write-Host "Invalid PCI device name" -ForegroundColor Red
        Write-Host "Exit...."
        exit
    }
}

for($i = 0 ; $i -lt $PCIeLinkSpeed.Count ;$i++)
{
    #validate user input PCIeLinkSpeed
    if($($PCIeLInkSpeedValidValues | where{$_ -eq $PCIeLinkSpeed[$i] }) -eq $null)
    {
        Write-Host "Invalid PCIeLinkSpeed value" -ForegroundColor Red
        Write-Host "Exit...."
        exit
    }
}

Write-Host "Configuring PCIDevice ....." -ForegroundColor Green  
$failureCount = 0
$cmdletInput = New-Object -TypeName psobject

if($PCIeLinkSpeed.Count -ne 0)
{
    $cmdletInput | Add-Member "PCIDevice" @(,$PCIDevice)
    $cmdletInput | Add-Member "PCIeLinkSpeed" @(,$PCIeLinkSpeed)
}
else
{
   $cmdletInput | Add-Member "PCIDevice" @(,$PCIDevice) 
}

if($ListOfConnection.Count -ne 0)
{
    if($EnablePCIDevice){

        $setResult = $cmdletInput | Set-HPEBIOSPCIDeviceConfiguration -Connection $ListOfConnection -EnablePCIDevice
    }
    elseif($DisablePCIDevice){

        $setResult = $cmdletInput | Set-HPEBIOSPCIDeviceConfiguration -Connection $ListOfConnection -DisablePCIDevice
    }
    else
    {
        $setResult = Set-HPEBIOSPCIDeviceConfiguration -Connection $ListOfConnection
    }
    
        if($setResult -ne $null -and ($setResult.Status -eq "Error"))
        {
            Write-Host ""
            Write-Host "PCI device configuration cannot be changed"
            Write-Host "Server : $($setResult.IP)"
            Write-Host "Error : $($setResult.StatusInfo)"
		    Write-Host "StatusInfo.Category : $($setResult.StatusInfo.Category)"
		    Write-Host "StatusInfo.Message : $($setResult.StatusInfo.Message)"
		    Write-Host "StatusInfo.AffectedAttribute : $($setResult.StatusInfo.AffectedAttribute)"
            $failureCount++
        }
}


if($failureCount -ne $ListOfConnection.Count)
{
    Write-Host ""
    Write-host "PCI device configuration successfully changed" -ForegroundColor Green
    Write-Host ""
    $counter = 1
    foreach($serverConnection in $ListOfConnection)
    {
        $getResult = $serverConnection | Get-HPEBIOSPCIDeviceConfiguration
        Write-Host "-------------------Server $($getResult.IP)-------------------" -ForegroundColor Yellow
        Write-Host ""
        $getResult.PCIDevice
        $counter ++
    }
}
    
Disconnect-HPEBIOS -Connection $ListOfConnection
$ErrorActionPreference = "Continue"
Write-Host "****** Script execution completed ******" -ForegroundColor Yellow
exit

# SIG # Begin signature block
# MIIjqAYJKoZIhvcNAQcCoIIjmTCCI5UCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBrE3CJWSVvq/JL
# FWdyUE9EZqQe90TG21LLqM4pKJ82/6CCHrMwggPuMIIDV6ADAgECAhB+k+v7fMZO
# WepLmnfUBvw7MA0GCSqGSIb3DQEBBQUAMIGLMQswCQYDVQQGEwJaQTEVMBMGA1UE
# CBMMV2VzdGVybiBDYXBlMRQwEgYDVQQHEwtEdXJiYW52aWxsZTEPMA0GA1UEChMG
# VGhhd3RlMR0wGwYDVQQLExRUaGF3dGUgQ2VydGlmaWNhdGlvbjEfMB0GA1UEAxMW
# VGhhd3RlIFRpbWVzdGFtcGluZyBDQTAeFw0xMjEyMjEwMDAwMDBaFw0yMDEyMzAy
# MzU5NTlaMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsayzSVRLlxwS
# CtgleZEiVypv3LgmxENza8K/LlBa+xTCdo5DASVDtKHiRfTot3vDdMwi17SUAAL3
# Te2/tLdEJGvNX0U70UTOQxJzF4KLabQry5kerHIbJk1xH7Ex3ftRYQJTpqr1SSwF
# eEWlL4nO55nn/oziVz89xpLcSvh7M+R5CvvwdYhBnP/FA1GZqtdsn5Nph2Upg4XC
# YBTEyMk7FNrAgfAfDXTekiKryvf7dHwn5vdKG3+nw54trorqpuaqJxZ9YfeYcRG8
# 4lChS+Vd+uUOpyyfqmUg09iW6Mh8pU5IRP8Z4kQHkgvXaISAXWp4ZEXNYEZ+VMET
# fMV58cnBcQIDAQABo4H6MIH3MB0GA1UdDgQWBBRfmvVuXMzMdJrU3X3vP9vsTIAu
# 3TAyBggrBgEFBQcBAQQmMCQwIgYIKwYBBQUHMAGGFmh0dHA6Ly9vY3NwLnRoYXd0
# ZS5jb20wEgYDVR0TAQH/BAgwBgEB/wIBADA/BgNVHR8EODA2MDSgMqAwhi5odHRw
# Oi8vY3JsLnRoYXd0ZS5jb20vVGhhd3RlVGltZXN0YW1waW5nQ0EuY3JsMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIBBjAoBgNVHREEITAfpB0wGzEZ
# MBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMTANBgkqhkiG9w0BAQUFAAOBgQADCZuP
# ee9/WTCq72i1+uMJHbtPggZdN1+mUp8WjeockglEbvVt61h8MOj5aY0jcwsSb0ep
# rjkR+Cqxm7Aaw47rWZYArc4MTbLQMaYIXCp6/OJ6HVdMqGUY6XlAYiWWbsfHN2qD
# IQiOQerd2Vc/HXdJhyoWBl6mOGoiEqNRGYN+tjCCBKMwggOLoAMCAQICEA7P9DjI
# /r81bgTYapgbGlAwDQYJKoZIhvcNAQEFBQAwXjELMAkGA1UEBhMCVVMxHTAbBgNV
# BAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1hbnRlYyBUaW1l
# IFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzIwHhcNMTIxMDE4MDAwMDAwWhcNMjAx
# MjI5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29y
# cG9yYXRpb24xNDAyBgNVBAMTK1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2Vydmlj
# ZXMgU2lnbmVyIC0gRzQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCi
# Yws5RLi7I6dESbsO/6HwYQpTk7CY260sD0rFbv+GPFNVDxXOBD8r/amWltm+YXkL
# W8lMhnbl4ENLIpXuwitDwZ/YaLSOQE/uhTi5EcUj8mRY8BUyb05Xoa6IpALXKh7N
# S+HdY9UXiTJbsF6ZWqidKFAOF+6W22E7RVEdzxJWC5JH/Kuu9mY9R6xwcueS51/N
# ELnEg2SUGb0lgOHo0iKl0LoCeqF3k1tlw+4XdLxBhircCEyMkoyRLZ53RB9o1qh0
# d9sOWzKLVoszvdljyEmdOsXF6jML0vGjG/SLvtmzV4s73gSneiKyJK4ux3DFvk6D
# Jgj7C72pT5kI4RAocqrNAgMBAAGjggFXMIIBUzAMBgNVHRMBAf8EAjAAMBYGA1Ud
# JQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDBzBggrBgEFBQcBAQRn
# MGUwKgYIKwYBBQUHMAGGHmh0dHA6Ly90cy1vY3NwLndzLnN5bWFudGVjLmNvbTA3
# BggrBgEFBQcwAoYraHR0cDovL3RzLWFpYS53cy5zeW1hbnRlYy5jb20vdHNzLWNh
# LWcyLmNlcjA8BgNVHR8ENTAzMDGgL6AthitodHRwOi8vdHMtY3JsLndzLnN5bWFu
# dGVjLmNvbS90c3MtY2EtZzIuY3JsMCgGA1UdEQQhMB+kHTAbMRkwFwYDVQQDExBU
# aW1lU3RhbXAtMjA0OC0yMB0GA1UdDgQWBBRGxmmjDkoUHtVM2lJjFz9eNrwN5jAf
# BgNVHSMEGDAWgBRfmvVuXMzMdJrU3X3vP9vsTIAu3TANBgkqhkiG9w0BAQUFAAOC
# AQEAeDu0kSoATPCPYjA3eKOEJwdvGLLeJdyg1JQDqoZOJZ+aQAMc3c7jecshaAba
# tjK0bb/0LCZjM+RJZG0N5sNnDvcFpDVsfIkWxumy37Lp3SDGcQ/NlXTctlzevTcf
# Q3jmeLXNKAQgo6rxS8SIKZEOgNER/N1cdm5PXg5FRkFuDbDqOJqxOtoJcRD8HHm0
# gHusafT9nLYMFivxf1sJPZtb4hbKE4FtAC44DagpjyzhsvRaqQGvFZwsL0kb2yK7
# w/54lFHDhrGCiF3wPbRRoXkzKy57udwgCRNx62oZW8/opTBXLIlJP7nPf8m/PiJo
# Y1OavWl0rMUdPH+S4MO8HNgEdTCCBUwwggM0oAMCAQICEzMAAAA12NVZWwZxQSsA
# AAAAADUwDQYJKoZIhvcNAQEFBQAwfzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEpMCcGA1UEAxMgTWljcm9zb2Z0IENvZGUgVmVyaWZpY2F0aW9u
# IFJvb3QwHhcNMTMwODE1MjAyNjMwWhcNMjMwODE1MjAzNjMwWjBvMQswCQYDVQQG
# EwJTRTEUMBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNVBAsTHUFkZFRydXN0IEV4
# dGVybmFsIFRUUCBOZXR3b3JrMSIwIAYDVQQDExlBZGRUcnVzdCBFeHRlcm5hbCBD
# QSBSb290MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAt/caM+byAAQt
# OeBOW+0fvGwPzbX6I7bO3psRM5ekKUx9k5+9SryT7QMa44/P5W1QWtaXKZRagLBJ
# etsulf24yr83OC0ePpFBrXBWx/BPP+gynnTKyJBU6cZfD3idmkA8Dqxhql4Uj56H
# oWpQ3NeaTq8Fs6ZxlJxxs1BgCscTnTgHhgKo6ahpJhiQq0ywTyOrOk+E2N/On+Fp
# b7vXQtdrROTHre5tQV9yWnEIN7N5ZaRZoJQ39wAvDcKSctrQOHLbFKhFxF0qfbe0
# 1sTurM0TRLfJK91DACX6YblpalgjEbenM49WdVn1zSnXRrcKK2W200JvFbK4e/vv
# 6V1T1TRaJwIDAQABo4HQMIHNMBMGA1UdJQQMMAoGCCsGAQUFBwMDMBIGA1UdEwEB
# /wQIMAYBAf8CAQIwHQYDVR0OBBYEFK29mHo0tCb3+sQmVO8DveAky1QaMAsGA1Ud
# DwQEAwIBhjAfBgNVHSMEGDAWgBRi+wohW39DbhHaCVRQa/XSlnHxnjBVBgNVHR8E
# TjBMMEqgSKBGhkRodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9k
# dWN0cy9NaWNyb3NvZnRDb2RlVmVyaWZSb290LmNybDANBgkqhkiG9w0BAQUFAAOC
# AgEANiui8uEzH+ST9/JphcZkDsmbYy/kcDeY/ZTse8/4oUJG+e1qTo00aTYFVXoe
# u62MmUKWBuklqCaEvsG/Fql8qlsEt/3RwPQCvijt9XfHm/469ujBe9OCq/oUTs8r
# z+XVtUhAsaOPg4utKyVTq6Y0zvJD908s6d0eTlq2uug7EJkkALxQ/Xj25SOoiZST
# 97dBMDdKV7fmRNnJ35kFqkT8dK+CZMwHywG2CcMu4+gyp7SfQXjHoYQ2VGLy7BUK
# yOrQhPjx4Gv0VhJfleD83bd2k/4pSiXpBADxtBEOyYSe2xd99R6ljjYpGTptbEZL
# 16twJCiNBaPZ1STy+KDRPII51KiCDmk6gQn8BvDHWTOENpMGQZEjLCKlpwErULQo
# rttGsFkbhrObh+hJTjkLbRTfTAMwHh9fdK71W1kDU+yYFuDQYjV1G0i4fRPleki4
# d1KkB5glOwabek5qb0SGTxRPJ3knPVBzQUycQT7dKQxzscf7H3YMF2UE69JQEJJB
# SezkBn02FURvib9pfflNQME6mLagfjHSta7K+1PVP1CGzV6TO21dfJo/P/epJViE
# 3RFJAKLHyJ433XeObXGL4FuBNF1Uusz1k0eIbefvW+Io5IAbQOQPKtF/IxVlWqyZ
# lEM/RlUm1sT6iJXikZqjLQuF3qyM4PlncJ9xeQIx92GiKcQwggVqMIIEUqADAgEC
# AhEAp7f+kfK8y/XKvnoKBpdAGDANBgkqhkiG9w0BAQsFADB9MQswCQYDVQQGEwJH
# QjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3Jk
# MRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDEjMCEGA1UEAxMaQ09NT0RPIFJT
# QSBDb2RlIFNpZ25pbmcgQ0EwHhcNMTcwNTI2MDAwMDAwWhcNMTgwNTI2MjM1OTU5
# WjCB0jELMAkGA1UEBhMCVVMxDjAMBgNVBBEMBTk0MzA0MQswCQYDVQQIDAJDQTES
# MBAGA1UEBwwJUGFsbyBBbHRvMRwwGgYDVQQJDBMzMDAwIEhhbm92ZXIgU3RyZWV0
# MSswKQYDVQQKDCJIZXdsZXR0IFBhY2thcmQgRW50ZXJwcmlzZSBDb21wYW55MRow
# GAYDVQQLDBFIUCBDeWJlciBTZWN1cml0eTErMCkGA1UEAwwiSGV3bGV0dCBQYWNr
# YXJkIEVudGVycHJpc2UgQ29tcGFueTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAJ6VdqLTjoGE+GPiPE8LxjEMKQOW/4rFUFPo9ZWeLYcyUdOZlYC+Hgpa
# /qJXVLcrhNqe0Cazv6FPIc0sjYtk8gfJW/al17nz+e9olqgE7mFtu/YiFb/HMbJz
# JINNfnvlIAQW5ECQv+HkSm2Lboa7YxzsWKLbY17gOz6cJYxDNLqTgyI4GWnaYeSd
# ZklzdmpxWMrLAlzImRwQl76si0MHtJ8mrSaGUewmLmb9QnFeznQx1igYk5CsiIua
# vmjCGjQo8mymiaeWz1cldGqw5GLEyEu5aV7bP0v0z7IwwwWtt+YP6PUK7gzJdboj
# Rmxc3aqDAwD6z4p2tm7qzVW7dgar4WcCAwEAAaOCAY0wggGJMB8GA1UdIwQYMBaA
# FCmRYP+KTfrr+aZquM/55ku9Sc4SMB0GA1UdDgQWBBTMsuK5LRcd3jjKKo4TK1nD
# /5BaiDAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggr
# BgEFBQcDAzARBglghkgBhvhCAQEEBAMCBBAwRgYDVR0gBD8wPTA7BgwrBgEEAbIx
# AQIBAwIwKzApBggrBgEFBQcCARYdaHR0cHM6Ly9zZWN1cmUuY29tb2RvLm5ldC9D
# UFMwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21vZG9jYS5jb20vQ09N
# T0RPUlNBQ29kZVNpZ25pbmdDQS5jcmwwdAYIKwYBBQUHAQEEaDBmMD4GCCsGAQUF
# BzAChjJodHRwOi8vY3J0LmNvbW9kb2NhLmNvbS9DT01PRE9SU0FDb2RlU2lnbmlu
# Z0NBLmNydDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuY29tb2RvY2EuY29tMA0G
# CSqGSIb3DQEBCwUAA4IBAQBkfKIfp8al8qz+C5b52vHoS7EoTFAtTQLo0HdyQgdw
# hy9DlOiA/1OLESM6tWeHfi4lgKlzWafwetY1khHAgYwB2IKklC1OBBSynm/pl4rM
# hRPrPoDp4OwGrsW5tpCRZ27lQ6pPrPWochPNOg7qo3qbHDFmZygdgC9/d1bZUk23
# /UNLaCnieBvUPoGwpD0W/fpocueFSOwy0D9Xbct5hvc8Vk3N9dg5+Ey1t9uaGxTa
# j3kbcpDuq9XnbbYrtNfFGihtX5EmeCX1mp56ifBgYWAGXueN7ZUliYwQGJqgsher
# RVU8EVh9kELgM9xmzxUM3ueGnFHNMibWXUKeZfQxjtVNMIIFdDCCBFygAwIBAgIQ
# J2buVutJ846r13Ci/ITeIjANBgkqhkiG9w0BAQwFADBvMQswCQYDVQQGEwJTRTEU
# MBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNVBAsTHUFkZFRydXN0IEV4dGVybmFs
# IFRUUCBOZXR3b3JrMSIwIAYDVQQDExlBZGRUcnVzdCBFeHRlcm5hbCBDQSBSb290
# MB4XDTAwMDUzMDEwNDgzOFoXDTIwMDUzMDEwNDgzOFowgYUxCzAJBgNVBAYTAkdC
# MRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQx
# GjAYBgNVBAoTEUNPTU9ETyBDQSBMaW1pdGVkMSswKQYDVQQDEyJDT01PRE8gUlNB
# IENlcnRpZmljYXRpb24gQXV0aG9yaXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAkehUktIKVrGsDSTdxc9EZ3SZKzejfSNwAHG8U9/E+ioSj0t/EFa9
# n3Byt2F/yUsPF6c947AEYe7/EZfH9IY+Cvo+XPmT5jR62RRr55yzhaCCenavcZDX
# 7P0N+pxs+t+wgvQUfvm+xKYvT3+Zf7X8Z0NyvQwA1onrayzT7Y+YHBSrfuXjbvzY
# qOSSJNpDa2K4Vf3qwbxstovzDo2a5JtsaZn4eEgwRdWt4Q08RWD8MpZRJ7xnw8ou
# tmvqRsfHIKCxH2XeSAi6pE6p8oNGN4Tr6MyBSENnTnIqm1y9TBsoilwie7SrmNnu
# 4FGDwwlGTm0+mfqVF9p8M1dBPI1R7Qu2XK8sYxrfV8g/vOldxJuvRZnio1oktLqp
# Vj3Pb6r/SVi+8Kj/9Lit6Tf7urj0Czr56ENCHonYhMsT8dm74YlguIwoVqwUHZwK
# 53Hrzw7dPamWoUi9PPevtQ0iTMARgexWO/bTouJbt7IEIlKVgJNp6I5MZfGRAy1w
# dALqi2cVKWlSArvX31BqVUa/oKMoYX9w0MOiqiwhqkfOKJwGRXa/ghgntNWutMtQ
# 5mv0TIZxMOmm3xaG4Nj/QN370EKIf6MzOi5cHkERgWPOGHFrK+ymircxXDpqR+DD
# eVnWIBqv8mqYqnK8V0rSS527EPywTEHl7R09XiidnMy/s1Hap0flhFMCAwEAAaOB
# 9DCB8TAfBgNVHSMEGDAWgBStvZh6NLQm9/rEJlTvA73gJMtUGjAdBgNVHQ4EFgQU
# u69+Aj36pvE8hI6t7jiY7NkyMtQwDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQF
# MAMBAf8wEQYDVR0gBAowCDAGBgRVHSAAMEQGA1UdHwQ9MDswOaA3oDWGM2h0dHA6
# Ly9jcmwudXNlcnRydXN0LmNvbS9BZGRUcnVzdEV4dGVybmFsQ0FSb290LmNybDA1
# BggrBgEFBQcBAQQpMCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVz
# dC5jb20wDQYJKoZIhvcNAQEMBQADggEBAGS/g/FfmoXQzbihKVcN6Fr30ek+8nYE
# bvFScLsePP9NDXRqzIGCJdPDoCpdTPW6i6FtxFQJdcfjJw5dhHk3QBN39bSsHNA7
# qxcS1u80GH4r6XnTq1dFDK8o+tDb5VCViLvfhVdpfZLYUspzgb8c8+a4bmYRBbMe
# lC1/kZWSWfFMzqORcUx8Rww7Cxn2obFshj5cqsQugsv5B5a6SE2Q8pTIqXOi6wZ7
# I53eovNNVZ96YUWYGGjHXkBrI/V5eu+MtWuLt29G9HvxPUsE2JOAWVrgQSQdso8V
# YFhH2+9uRv0V9dlfmrPb2LjkQLPNlzmuhbsdjrzch5vRpu/xO28QOG8wggXgMIID
# yKADAgECAhAufIfMDpNKUv6U/Ry3zTSvMA0GCSqGSIb3DQEBDAUAMIGFMQswCQYD
# VQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdT
# YWxmb3JkMRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDErMCkGA1UEAxMiQ09N
# T0RPIFJTQSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTAeFw0xMzA1MDkwMDAwMDBa
# Fw0yODA1MDgyMzU5NTlaMH0xCzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVy
# IE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGjAYBgNVBAoTEUNPTU9ETyBD
# QSBMaW1pdGVkMSMwIQYDVQQDExpDT01PRE8gUlNBIENvZGUgU2lnbmluZyBDQTCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKaYkGN3kTR/itHd6WcxEevM
# Hv0xHbO5Ylc/k7xb458eJDIRJ2u8UZGnz56eJbNfgagYDx0eIDAO+2F7hgmz4/2i
# aJ0cLJ2/cuPkdaDlNSOOyYruGgxkx9hCoXu1UgNLOrCOI0tLY+AilDd71XmQChQY
# USzm/sES8Bw/YWEKjKLc9sMwqs0oGHVIwXlaCM27jFWM99R2kDozRlBzmFz0hUpr
# D4DdXta9/akvwCX1+XjXjV8QwkRVPJA8MUbLcK4HqQrjr8EBb5AaI+JfONvGCF1H
# s4NB8C4ANxS5Eqp5klLNhw972GIppH4wvRu1jHK0SPLj6CH5XkxieYsCBp9/1QsC
# AwEAAaOCAVEwggFNMB8GA1UdIwQYMBaAFLuvfgI9+qbxPISOre44mOzZMjLUMB0G
# A1UdDgQWBBQpkWD/ik366/mmarjP+eZLvUnOEjAOBgNVHQ8BAf8EBAMCAYYwEgYD
# VR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDAzARBgNVHSAECjAI
# MAYGBFUdIAAwTAYDVR0fBEUwQzBBoD+gPYY7aHR0cDovL2NybC5jb21vZG9jYS5j
# b20vQ09NT0RPUlNBQ2VydGlmaWNhdGlvbkF1dGhvcml0eS5jcmwwcQYIKwYBBQUH
# AQEEZTBjMDsGCCsGAQUFBzAChi9odHRwOi8vY3J0LmNvbW9kb2NhLmNvbS9DT01P
# RE9SU0FBZGRUcnVzdENBLmNydDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuY29t
# b2RvY2EuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQACPwI5w+74yjuJ3gxtTbHxTpJP
# r8I4LATMxWMRqwljr6ui1wI/zG8Zwz3WGgiU/yXYqYinKxAa4JuxByIaURw61OHp
# Cb/mJHSvHnsWMW4j71RRLVIC4nUIBUzxt1HhUQDGh/Zs7hBEdldq8d9YayGqSdR8
# N069/7Z1VEAYNldnEc1PAuT+89r8dRfb7Lf3ZQkjSR9DV4PqfiB3YchN8rtlTaj3
# hUUHr3ppJ2WQKUCL33s6UTmMqB9wea1tQiCizwxsA4xMzXMHlOdajjoEuqKhfB/L
# YzoVp9QVG6dSRzKp9L9kR9GqH1NOMjBzwm+3eIKdXP9Gu2siHYgL+BuqNKb8jPXd
# f2WMjDFXMdA27Eehz8uLqO8cGFjFBnfKS5tRr0wISnqP4qNS4o6OzCbkstjlOMKo
# 7caBnDVrqVhhSgqXtEtCtlWdvpnncG1Z+G0qDH8ZYF8MmohsMKxSCZAWG/8rndvQ
# IMqJ6ih+Mo4Z33tIMx7XZfiuyfiDFJN2fWTQjs6+NX3/cjFNn569HmwvqI8MBlD7
# jCezdsn05tfDNOKMhyGGYf6/VXThIXcDCmhsu+TJqebPWSXrfOxFDnlmaOgizbjv
# mIVNlhE8CYrQf7woKBP7aspUjZJczcJlmAaezkhb1LU3k0ZBfAfdz/pD77pnYf99
# SeC7MH1cgOPmFjlLpzGCBEswggRHAgEBMIGSMH0xCzAJBgNVBAYTAkdCMRswGQYD
# VQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGjAYBgNV
# BAoTEUNPTU9ETyBDQSBMaW1pdGVkMSMwIQYDVQQDExpDT01PRE8gUlNBIENvZGUg
# U2lnbmluZyBDQQIRAKe3/pHyvMv1yr56CgaXQBgwDQYJYIZIAWUDBAIBBQCgfDAQ
# BgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgdn88+QGn
# 60JFdBWd3O8x8zTTv0MsjmRl4zflZnVPbmwwDQYJKoZIhvcNAQEBBQAEggEAamYY
# d3Ixz0xQpq91vD4rwpSCFXamhBISPfzt0jSY1n1INKjJWc36Vu+AIJ/VeBeOXFIO
# D+FUHySAQk8qk7U0tE9/is/ftWUVv8aGjRAQy6E43ZxiUQA0A6r5pUzNm9xZQRkj
# k/gc+FlWhxR1WPUm7h8jKIib5bVOgpw7QBhWxnAoJm27sp8EfZhLFKcs0ji0M6ou
# xp5yi1Te4VFfXP1OO2QkAijg2O3ufua6YHxnm92payAdTXpxhgAvdwhbBe70nkTM
# 6nssn20yHwlqxCyGXOphMpme/Lxq8CgIAa6f5suq4mbGAVRcM3ERAqZzXZP+6Iyo
# X1f0SG/zlFE86w4fzKGCAgswggIHBgkqhkiG9w0BCQYxggH4MIIB9AIBATByMF4x
# CzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEwMC4G
# A1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBDQSAtIEcyAhAO
# z/Q4yP6/NW4E2GqYGxpQMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJKoZI
# hvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xODAzMDkxMDExMjhaMCMGCSqGSIb3DQEJ
# BDEWBBRqFEPA46soMdVjpVWTbzT+A6bZ7jANBgkqhkiG9w0BAQEFAASCAQAeCUn4
# UiSCNulaLwNPAfQegHD+jS27fzq6qxf52PiBsDepFxDUR8wxzGzU4fCtvJ7/l7Fz
# q3AxHCgAZSD4vvC84WkpA1ppDAc2b5Ws61XNpCgO2FHZW7JC7o+kGjPlZjESYgIX
# 1PfKDvpEahst06W9NKG+z8QXSpiepdO2icFFdxzr3Sd375xfPV2lT+NBHwsiEP8D
# zlEYx3Sz+V933LYy4ntcDsVtxhyNkY3PO1sYLTXCcDGtU4C5Qi+Tc5GZk5ILtSuI
# z9gEfYODfdJ5gyfFrJmJRLq5J4pzVpwb9IzKjBnoJYoXH/Ok7HbVzAVXG0Bn4amw
# JCMX5xJt7YXmTlSB
# SIG # End signature block
