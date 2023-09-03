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
