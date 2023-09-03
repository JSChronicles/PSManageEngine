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
