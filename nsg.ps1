$ErrorActionPreference="Stop"
$ase_region_nsg = "[ app service environment region ]"

$virtualNetworkName = "Group contososports ContosoSportsLeague"
$subnetName = "Subnet-1"

[xml]$activeIPS = Get-Content $PSScriptRoot\azure-public-ips.xml


New-AzureNetworkSecurityGroup -Name "nsg-contoso-exp-ase" `
                    -Location $ase_region_nsg `
                    -Label "Locks down outgoing requests from Web App in ASE" 


Write-Host "Allowing Inbound Internet Access" -ForegroundColor Green
Get-AzureNetworkSecurityGroup -Name "nsg-contoso-exp-ase" |
Set-AzureNetworkSecurityRule -Name "ALLOW INTERNET IN" `
    -Type Inbound `
    -Priority 1000 `
    -Action Allow `
    -SourceAddressPrefix 'INTERNET'  `
    -SourcePortRange '*' `
    -DestinationAddressPrefix '*' `
    -DestinationPortRange '*' -Protocol "*"  

Write-Host "Allowing Access to Payment Gateway" -ForegroundColor Green

# Payment API
Get-AzureNetworkSecurityGroup -Name "nsg-contoso-exp-ase" |
    Set-AzureNetworkSecurityRule -Name "ALLOW TRUSTED PAYMENT API" `
        -Type Outbound `
        -Priority 1000 `
        -Action Allow `
        -SourceAddressPrefix '*'  `
        -SourcePortRange '*' `
        -DestinationAddressPrefix '191.236.106.123' `
        -DestinationPortRange '443' `
        -Protocol "*" 

Write-Host "Allowing Outbound Access to Azure Core Services" -ForegroundColor Green
$ase_region_xml = $null

# Map the region to the region name in the XML file since they don't match
switch($ase_region_nsg)
{
    "West Europe"{
        $ase_region_xml = "europewest"
        break
    }
    "East US"{
        $ase_region_xml = "useast"
        break
    }
    "East US 2"{
        $ase_region_xml = "useast2"
        break
    }
    "West US"{
        $ase_region_xml = "uswest"
        break
    }
    "North Central US"{
        $ase_region_xml = "usnorth"
        break
    }
    "North Europe"{
        $ase_region_xml = "europenorth"
        break
    }
    "Central US"{
        $ase_region_xml = "uscentral"
        break
    }
    "East Asia"{
        $ase_region_xml = "asiaeast"
        break
    }
    "Southeast Asia"{
        $ase_region_xml = "asiasoutheast"
        break
    }
    "South Central US"{
        $ase_region_xml = "ussouth"
        break
    }
    "Japan West"{
        $ase_region_xml = "japanwest"
        break
    }
    "Japan East"{
        $ase_region_xml = "japaneast"
        break
    }
    "Brazil South"{
        $ase_region_xml = "brazilsouth"
        break
    }
    "Australia East"{
        $ase_region_xml = "australiaeast"
        break
    }
    "Australia Southeast"{
        $ase_region_xml = "australiasoutheast"
        break
    }
}

if($ase_region_xml -eq $null)
{
    Write-Error "Azure region: [ $ase_region_ase ] was not found in mapping." 
    return 
}


$regions = $activeIPS.AzurePublicIpAddresses.Region
foreach($region in $regions){
    switch($region.Name)
    {
        $ase_region_xml
        {
            $waiprulepriority = 100
            foreach($ip in $region.IpRange)
            {
                $subnet = $ip.Subnet
                Get-AzureNetworkSecurityGroup -Name "nsg-contoso-exp-ase" |
                    Set-AzureNetworkSecurityRule -Name "AzureIP$waiprulepriority" `
                    -Type Outbound `
                    -Priority $waiprulepriority `
                    -Action Allow `
                    -SourceAddressPrefix '*'  `
                    -SourcePortRange '*' `
                    -DestinationAddressPrefix "$subnet" `
                    -DestinationPortRange '*' `
                    -Protocol "*" 

                $waiprulepriority++
            }
            break
        }
    }
}

Write-Host "Restricting Outbound Access" -ForegroundColor Yellow

Get-AzureNetworkSecurityGroup -Name "nsg-contoso-exp-ase" |
    Set-AzureNetworkSecurityRule -Name "DENY OUTBOUND" `
        -Type Outbound `
        -Priority 2000 `
        -Action Deny `
        -SourceAddressPrefix '*'  `
        -SourcePortRange '*' `
        -DestinationAddressPrefix 'INTERNET' `
        -DestinationPortRange '*' `
        -Protocol "*"

Write-Host "Associating Network Security Group with App Service Environment" -ForegroundColor Green

Get-AzureNetworkSecurityGroup -Name "nsg-contoso-exp-ase" | `
    Set-AzureNetworkSecurityGroupToSubnet `
    -VirtualNetworkName $virtualNetworkName `
    -SubnetName $subnetName -Force
 
Write-Host "Network Security Group Configuration Complete!" -ForegroundColor Green
