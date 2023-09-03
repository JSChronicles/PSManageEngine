# Purpose of this script is just a show case for removing computers from PMP that are no longer in on-prem AD.
function Get-MEAuthToken {
    <#
    .SYNOPSIS
        Obtain Auth Token
    .DESCRIPTION
        Obtain Auth Token by using the username, then password as UTF8 bytes and then encoding to base64 string, and domain.
        If MFA is enabled then add a wait and read command for the OTP. This all uses ad_authentication as the auth_type.
    .PARAMETER URI
        URI that the service uses, example 'https://pmp123:6383'
    .PARAMETER Domain
        Domain that the service uses, example 'Contoso' from Contoso.root.local
    .PARAMETER Credential
        Set of credentials you would like to use.
    .INPUTS
        Description of objects that can be piped to the script.
    .OUTPUTS
        Description of objects that are output by the script.
    .EXAMPLE
        Get-MEAuthToken -URI "https://pmp123:6383" -Domain "Contoso" -Credential (Get-Credential)
    .EXAMPLE
        $token = Get-MEAuthToken -URI "https://pmp123:6383" -Domain "Contoso" -Credential (Get-Credential)
    .LINK
        https://www.manageengine.com/products/desktop-central/api/index.html
    .NOTES
        Detail on what the script does, if this is needed.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory,
            Position = 0,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$URI,

        [Parameter(Mandatory,
            Position = 1,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Domain,

        [Parameter(Mandatory,
            Position = 2,
            ValueFromPipeline)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty

    )

    begin {

        try {
            function Read-OTP {
                <#
                .SYNOPSIS
                    Prompts for OTP code
                .DESCRIPTION
                    Prompts for OTP code and verifies the pattern/range that is provided. Then it provides a final prompt on the screen
                    asking if this is what you wanted. If the prompt is provided a "NO" then the script exits.
                .PARAMETER Cluster
                    Switch
                .INPUTS
                    Description of objects that can be piped to the script.
                .OUTPUTS
                    text value
                .EXAMPLE
                    Read-OTP -OTP "123456"
                #>
                [CmdletBinding()]
                [OutputType([System.Int32])]
                param (
                    [Parameter(Mandatory,
                        Position = 0,
                        ValueFromPipeline)]
                    [int]$OTP
                )
                begin {
                    try {

                        Write-Verbose -Message "Building System Management Automation Host Choice Descriptions..."

                        # Message confirmation prompt
                        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Description."
                        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Description."
                        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
                        $title = "OTP Code"
                        $message = "You chose $OTP, is this correct?"
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($PSItem)
                    }
                }
                process {
                    try {
                        $result = $host.ui.PromptForChoice($title, $message, $options, 1)
                        switch ($result) {
                            0 {
                                $OTP
                            }1 {
                                Return
                            }
                        }
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($PSItem)
                    }
                }
                end {

                }

            }

            $convertedPassword = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Credential.GetNetworkCredential().password))

            $headers = @{
                "Content-Type" = "application/json"
            }

            $body = @"
            {
                "username":"$($Credential.GetNetworkCredential().UserName)",
                "password":"$convertedPassword",
                "auth_type":"ad_authentication",
                "domainName":"$Domain"
            }
"@

            $Params = @{
                Method  = "POST"
                URI     = "$URI/api/1.4/desktop/authentication"
                Headers = $headers
                Body    = $body
            }

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }

    }

    process {

        try {
            $token = Invoke-RestMethod @Params

            if ([bool]($token.message_response.authentication.two_factor_data.is_TwoFactor_Enabled)) {

                $OTP = Read-OTP
                $Params.URI = "$URI/api/1.4/desktop/authentication/otpValidate"
                $Params.Body = @"
                {
                    "uid":"$($token.message_response.authentication.two_factor_data.unique_userID)",
                    "otp":"$OTP",
                    "rememberme_enabled":"true"
                }
"@
                $token = Invoke-RestMethod @Params
            }

            $token.message_response.authentication.auth_data.auth_token
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }

    end {

    }
}

function Get-MEComputer {
    <#
    .SYNOPSIS
        Retrieve the som computers list.
    .DESCRIPTION
        Lists all the computers and their related patch manager plus agent details
    .PARAMETER URI
        URI that the service uses, example 'https://pmp123:6383'
    .PARAMETER ResourceID
        Requires the int value of the resource id
    .PARAMETER Token
        Auth Token
    .INPUTS
        Description of objects that can be piped to the script.
    .OUTPUTS
        Description of objects that are output by the script.
    .EXAMPLE
        Get-MEComputer -URI "https://pmp123:6383" -Token $token
    .EXAMPLE
        Get-MEComputer -URI "https://pmp123:6383" -Resource 123 -Token $token
    .LINK
        https://www.manageengine.com/products/desktop-central/api/index.html
        https://www.manageengine.com/products/desktop-central/api/api-som-view.html
        https://www.manageengine.com/products/desktop-central/api/api-som-computers.html
    .NOTES
        Detail on what the script does, if this is needed.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory,
            Position = 0,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$URI,

        [Parameter(
            Position = 1,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [int]$ResourceID,

        [Parameter(Mandatory,
            Position = 2,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        $Token
    )

    begin {

        try {

            $headers = @{
                'Authorization' = "$Token"
            }

            $Params = @{
                Method  = "GET"
                URI     = "$URI/api/1.4/som/computers"
                Headers = $headers
            }

            if ($PSBoundParameters.ContainsKey('ResourceID')) {
                $Params.URI = "$($Params.URI)?residfilter=$ResourceID"
            }
            else {
                $Params.URI = "$($Params.URI)?page=0&pagelimit=10000"
            }

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }

    }

    process {

        try {
            Invoke-RestMethod @Params
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }

    end {

    }
}

function Remove-MEComputer {
    <#
    .SYNOPSIS
        Remove Agent actions on computers
    .DESCRIPTION
        Remove details of a computer managed by Patch Manager Plus.
    .PARAMETER URI
        URI that the service uses, example 'https://pmp123:6383'
    .PARAMETER ResourceID
        Requires the int value of the resource id
    .PARAMETER Token
        Auth Token
    .INPUTS
        Description of objects that can be piped to the script.
    .OUTPUTS
        Description of objects that are output by the script.
    .EXAMPLE
        Remove-MEComputer -URI "https://pmp123:6383" -Resource 123 -Token <token here>
    .EXAMPLE
        Remove-MEComputer -URI "https://pmp123:6383" -ResourceID 123,324,456 -Token <token here>
    .EXAMPLE
        Remove-MEComputer -URI "https://pmp123:6383" -ResourceID 123,324,456 -Token <token here> -WhatIf
    .LINK
        https://www.manageengine.com/products/desktop-central/api/api-som-computer-actions.html
    .NOTES
        Detail on what the script does, if this is needed.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory,
            Position = 0,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$URI,

        [Parameter(
            Position = 1,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [int]$ResourceID,

        [Parameter(Mandatory,
            Position = 2,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        $Token
    )

    begin {

        try {
            $IDs = ($ResourceID -join ',')

            $headers = @{
                'Authorization' = "$Token"
                "Content-Type"  = "application/json"
            }

            $Params = @{
                Method  = "POST"
                URI     = "$URI/api/1.4/som/computers/removecomputer"
                Headers = $headers
                Body    = @"
                {
                    "resourceids": [
                        $IDs
                    ]
                }
"@
            }

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }

    }

    process {

        try {
            if ($PSCmdlet.ShouldProcess("Resource ID: $IDs", "Remove Computer")) {
                Invoke-RestMethod @Params
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }

    end {

    }
}


function Compare-ADComputer {
    <#
    .SYNOPSIS
        Compare a list to of computers names to what is in AD.
    .DESCRIPTION
        Compare a list to of computers names to what is in AD. If the computername doesn't exist in AD then it will output it.
    .PARAMETER ComputerName
        Name of the computer(s) you wish to compare
    .INPUTS
        Description of objects that can be piped to the script.
    .OUTPUTS
        Description of objects that are output by the script.
    .EXAMPLE
        Compare-ADComputer -ComputerName "computername"
    .EXAMPLE
        Compare-ADComputer -ComputerName "computername" -Verbose
    .EXAMPLE
        $token = Get-MEAuthToken -Credential (Get-Credential) -Domain "Contoso"
        $data = Get-MEComputer -Token $token
        $removePMPComputers = Compare-ADComputer -ComputerName $data.message_response.computers.resource_name
    .LINK
        Links to further documentation.
    .NOTES
        Detail on what the script does, if this is needed.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName
    )

    begin {
        try {
            Write-Verbose -Message "Building AD list..."
            $ADComputers = Get-ADComputer -Filter * -Properties Name, DistinguishedName | Select-Object Name, DistinguishedName
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem)
        }
    }

    process {
        Write-Verbose -Message "Comparing AD list to computer names provided..."
        foreach ($Computer in $ComputerName) {
            if ($Computer -notin $ADComputers.name) {
                $Computer
            }
        }
    }

    end {

    }
}

$token = Get-MEAuthToken -Credential (Get-Credential) -Domain "Contoso"

$data = Get-MEComputer -Token $token

$removePMPComputers = Compare-ADComputer -ComputerName $data.message_response.computers.resource_name

$resourceids = foreach ($removePMPComputer in $removePMPComputers) {
    ($data.message_response.computers.Where({ $PSItem.resource_name -match "^$removePMPComputer$" })) | Select-Object resource_id, resource_name
}

Remove-MEComputer -ResourceID $resourceids.resource_id -Token $token
