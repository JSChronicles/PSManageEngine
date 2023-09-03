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
