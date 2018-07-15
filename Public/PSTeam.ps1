function Repair-Text {
    [CmdletBinding()]
    param(
        [string] $Text
    )
    if ($Text -ne $null) {
        $Text = $Text.ToString().Replace('"', '\"').Replace('\', '\\').Replace("`n", '\n\n').Replace("`r", '').Replace("`t", '\t')
        $Text = [System.Text.RegularExpressions.Regex]::Unescape($($Text))
    }
    if ($Text -eq '') { $Text = ' ' }
    return $Text
}
function Get-Image {
    [CmdletBinding()]
    param(
        [string] $PathToImages,
        [string] $FileName,
        [string] $FileExtension
    )
    Write-Verbose "Get-Image - PathToImages $PathToImages FileName $FileName FileExtension $FileExtension"
    if ($ImageType -ne [ImageType]::None) {
        $ImagePath = "$PathToImages\$($FileName)$FileExtension"
        Write-Verbose "Get-Image - ImagePath $ImagePath"
        if (Test-Path $ImagePath) {
            $Image = [convert]::ToBase64String((Get-Content $ImagePath -Encoding byte))
            Write-Verbose "Get-Image - Image Type: $($Image.GetType())"
            return "data:image/png;base64,$Image"
        }
    }
    return ''
}
function Convert-FromColor {
    [CmdletBinding()]
    param(
        [nullable[System.Drawing.Color]]$Color
    )
    if ($Color -ne $null) {
        $Value = $Color.R, $Color.G, $Color.B
        foreach ($arg in $Value) {
            $hexval = $hexval + [Convert]::ToString($arg, 16).ToUpper()
        }
        return "#$($hexval)" # .Substring(2)
    } else { '' }
}

function Add-TeamsMessageButtons {
    param(
        $buttons
    )
    $PotentialAction = @()
    foreach ($button in $buttons) {
        $PotentialAction += @{
            '@context' = 'http://schema.org'
            '@type'    = 'ViewAction'
            name       = $($button.Name)
            target     = @("$($button.Value)")
        }
    }
    return $PotentialAction
}
function Add-TeamsSection {
    param(
        $Sections
    )
    $PreparedSections = @()
    foreach ($section in $Sections) {
        $PreparedSections += $section
    }
    return $PreparedSections
}

function Add-TeamsBody {
    param (
        $MessageTitle,
        $ThemeColor,
        $Text,
        $Sections,
        $Type
    )

    $Body = ConvertTo-Json -Depth 6 @{
        title             = "$MessageTitle"
        themeColor        = "$ThemeColor"
        $([string] $Type)	= Repair-Text $($Text)
        sections          = $Sections

    }
    return $Body
}

function New-TeamsSection {
    [CmdletBinding()]
    param (
        [string[]] $Title = @(),
        [string[]] $ActivityTitle = @(),
        [string[]] $ActivitySubtitle = @(),
        [string[]] $ActivityImageLink = @(),
        $ActivityImage = @(),
        [string[]] $ActivityText = @(),
        [hashtable[]] $ActivityDetails = @(),
        [hashtable[]] $Buttons = @()
    )

    $Sections = @()
    for ($i = 0; $i -lt $ActivityTitle.Length; $i++) {
        $Sections += @{
            title            = $Title[$i]
            activityTitle    = "$($ActivityTitle[$i])"
            activitySubtitle = "$($ActivitySubtitle[$i])"
            activityImage    = "$($ActivityImageLink[$i])"
            activityText     = "$($ActivityText[$i])"
            #facts            = $ActivityDetails[$i]
            #  potentialAction  = @(
            #    $Buttons
            # )
        }
    }
    return $Sections
}

function New-TeamsButton {
    [CmdletBinding()]
    param (
        [string[]] $Name,
        [string[]] $Link
    )
    $Buttons = @()
    for ($i = 0; $i -lt $Name.Length; $i++) {
        $Buttons += @{ name = "$($Name[$i])" ; value = "$($Link[$i])" }
    }
    return $Buttons
}

function Send-TeamsMessage {
    [CmdletBinding()]
    Param (
        [alias("TeamsID")][Parameter(Mandatory = $true)][string]$URI,
        [hashtable[]]$Sections,
        [TeamsType]$Type = [TeamsType]::Summary,
        [string]$Text,
        [string]$MessageTitle,
        [string]$ActivityTitle,
        [string]$ActivitySubtitle,
        [array]$details = $null,
        [string]$detailTitle,
        [nullable[System.Drawing.Color]]$Color,
        [array]$Buttons = $null,
        [ImageType]$ImageType = [ImageType]::None,
        [switch]$ImageLink,
        [bool] $Supress = $true
    )
    $StoredImages = "$(Split-Path -Path $PSScriptRoot -Parent)\Images"
    Write-Verbose "Send-TeamsMessage - Get-Image()"
    $Image = Get-Image -PathToImages $StoredImages -FileName $ImageType -FileExtension '.jpg' -Verbose
    $ThemeColor = Convert-FromColor -Color $Color
    Write-Verbose "Send-TeamsMessage - Color $Color"
    Write-Verbose "Send-TeamsMessage - Color HEX $ThemeColor"


    $Body = Add-TeamsBody -MessageTitle $MessageTitle -ThemeColor $ThemeColor -Text $Text -Sections $Sections -Type $Type
    $Execute = Invoke-RestMethod -uri $uri -Method Post -body $Body -ContentType 'application/json'
    Write-Verbose "Send-TeamChannelMessage - Body $Body"
    Write-Verbose "Send-TeamChannelMessage - Execute $Execute"
    if ($Supress) { } else { return $Body }

}


function Send-TeamsMessage1 {
    [CmdletBinding()]
    Param (
        [alias("TeamsID")][Parameter(Mandatory = $true)][string]$URI,
        [TeamsType]$Type = [TeamsType]::Summary,
        [string]$Text,
        [string]$MessageTitle,
        [string]$ActivityTitle,
        [string]$ActivitySubtitle,
        [array]$details = $null,
        [string]$detailTitle,
        [nullable[System.Drawing.Color]]$Color,
        [array]$Buttons = $null,
        [ImageType]$ImageType = [ImageType]::None,
        [switch]$ImageLink,
        [bool] $Supress = $true,
        $Sections
    )
    $StoredImages = "$(Split-Path -Path $PSScriptRoot -Parent)\Images"
    $Image = Get-Image -PathToImages $StoredImages -FileName $ImageType -FileExtension '.jpg' -Verbose
    $ThemeColor = Convert-FromColor -Color $Color
    Write-Verbose "Send-TeamsMessage - Color $Color"
    Write-Verbose "Send-TeamsMessage - Color HEX $ThemeColor"

    $PotentialAction = Add-TeamsMessageButtons $Buttons

    $Section1 = @{
        activityTitle    = $ActivityTitle
        activitySubtitle = $ActivitySubtitle
        activityImage    = $Image
    }
    $Section2 = @{
        title           = $detailTitle
        facts           = $details
        potentialAction = @(
            $PotentialAction
        )
    }
    $Section3 = @{
        title            = "something new"
        potentialAction  = @(
            $PotentialAction
        )
        activityTitle    = "**Elon Musk**"
        activitySubtitle = "@elonmusk - 9/12/2016 at 5:33pm"
        activityImage    = "https://pbs.twimg.com/profile_images/782474226020200448/zDo-gAo0.jpg"
        activityText     = "Climate change explained in comic book form by xkcd xkcd.com/1732"
        facts            = $details

    }
    $Section4 = @{
        activityTitle    = "**Mark Knopfler**"
        activitySubtitle = "@MarkKnopfler - 9/12/2016 at 1:12pm"
        activityImage    = "https://pbs.twimg.com/profile_images/378800000221985528/b2ebfafca6fd7b565fdf3bf4ccdb4dc9.jpeg"
        activityText     = "Mark Knopfler features on B.B King's all-star album of Blues greats, released on this day in 2005..."
    }
    #  $Section3


    #  $Sections = Add-TeamsSection $Section1, $Section2, $Section3, $Section4, $Section4
    $Sections = Add-TeamsSection $Section1, $Section4
    $Body = Add-TeamsBody -MessageTitle $MessageTitle -ThemeColor $ThemeColor -Text $Text -Sections $Sections -Type $Type
    $Execute = Invoke-RestMethod -uri $uri -Method Post -body $Body -ContentType 'application/json'
    Write-Verbose "Send-TeamChannelMessage - Body $Body"
    Write-Verbose "Send-TeamChannelMessage - Execute $Execute"
    if ($Supress) { } else { return $Body }

}

function Send-TeamsMessageBody {
    param (
        [string] $uri,
        [string] $body
    )
    $Execute = Invoke-RestMethod -uri $uri -Method Post -body $body -ContentType 'application/json'
}