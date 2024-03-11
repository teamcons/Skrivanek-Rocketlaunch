﻿
Write-Output "[START] Loading internal functions"


Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[void] [System.Windows.Forms.Application]::EnableVisualStyles() 

#================================================================
function load_template{
    param (  
        [System.Windows.Forms.DataGridView]$GRID,
        [string]$FILE)
    try {
        $detectedtemplate = (Import-Csv -Delimiter $TEMPLATEDELIMITER -Path $FILE -Header "Name","00","01","02","03","04","05","06","07","08","09")
        foreach ($row in $detectedtemplate)
        {
            [void]$GRID.Rows.Add($row."Name",$row."00",$row."01",$row."02",$row."03",$row."04",$row."05",$row."06",$row."07",$row."08",$row."09");
        }
    }
    catch {
        Write-Output "[ERROR] Cannot load templates, falling back to default"
        $GRID.Rows.Add("Minimal","info","orig");
    }
    return $GRID
}



#================================================================
function Get-CompanyName {
    param([string]$mailadress)
    $mailadress -match "@(?<content>).*"
    $attempt_at_companyname         = $matches[0].trim("@").split(".")[0]
    $attempt_at_companyname         = [cultureinfo]::GetCultureInfo("de-DE").TextInfo.ToTitleCase($attempt_at_companyname)
    return $attempt_at_companyname
}


#==========================================
# Try to predict what next number would be 
function Predict-StructCode {
 
    Set-Location $ROOTSTRUCTURE
    Set-Location (Get-ChildItem 2024_* -Directory | Select-Object -Last 1)   
    $PREDICT_CODE                               =  (Get-ChildItem -Directory | Select-Object -Last 1).Name.Substring(5,4)
    [int]$PREDICT_CODE                   =  [int]$PREDICT_CODE + 1
    [bool]$script:CODE_PREDICTED                = $true
  
    return $PREDICT_CODE
    #$PREDICT_CODE = -join($YEAR,"-")
}





#================================================================
function Get-CleanifiedCodename {
    param([string]$PROJECTNAME)
    
    # Empty, so go on with what was initially predicted
    if ("$PROJECTNAME" -notmatch "^[0-9]" )
    {

        $PROJECTNAME = -join($PREDICT_CODE,$PROJECTNAME)
        Write-Output "Its words. Now: $PROJECTNAME"
    }

    # Remove invalid character, just in case
    $PROJECTNAME = $PROJECTNAME.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
    #Write-Output "Removed invalid. Now: $PROJECTNAME"


    # is it missing zeros
    if ($PROJECTNAME -match "^[0-9][0-9][0-9]")
    {
        $PROJECTNAME = -join("0",$PROJECTNAME)
        #Write-Output "Missing first zero. Now: $PROJECTNAME"

    }
    elseif ($PROJECTNAME -match "^[0-9][0-9]")
    {
        $PROJECTNAME = -join("00",$PROJECTNAME)
        #Write-Output "Missing two zero. Now: $PROJECTNAME"
    }
    elseif ($PROJECTNAME -match "^[0-9]")
    {
        $PROJECTNAME = -join("000",$PROJECTNAME)
        #Write-Output "Missing three zero. Now: $PROJECTNAME"
    }

    # Add year
    $PROJECTNAME = -join($YEAR,"-",$PROJECTNAME)
    Write-Output "[INPUT] Got: $PROJECTNAME"
 
    return $PROJECTNAME
}






#================================================================
# Rebuilt the whole tree
# Take a valid project name
function Rebuild-Tree{
    param([string]$projectname)

    # Check if correct, as wrong input could be real bad
    Write-Output "[Rebuild-Tree] Rebuild whole tree - got $projectname"
    try { $DIRCODE = $projectname.SubString(0, 9) }
    catch {
        $ERRORTEXT="Projektcode ist unpassend !!!
    Format: 20[0-9][0-9]\-[0-9][0-9][0-9][0-9] + Name
    Angegeben: $PROJECTCODE"
        $btn = [System.Windows.Forms.MessageBoxButtons]::OK
        $ico = [System.Windows.Forms.MessageBoxIcon]::Information
        Add-Type -AssemblyName System.Windows.Forms 
        [void] [System.Windows.Forms.MessageBox]::Show($ERRORTEXT,$APPNAME,$btn,$ico)
    exit }


    # REBUILT THE WHOLE TREE
    # Its in... year, underscore
    $BASEFOLDER     = -join($ROOTSTRUCTURE,$DIRCODE.Substring(0,4),"_")
    $BASEFOLDER     = -join($BASEFOLDER,$DIRCODE.Substring(5,2),"00-",$DIRCODE.Substring(5,2),"99")

    # If the folder with project numbers in range do not exist, just create it lol
    if (!(Test-Path $BASEFOLDER -PathType Container)) {
        Write-Output "[CREATE] Range folder in tree: $BASEFOLDER"
        New-Item -ItemType Directory -Force -Path "$BASEFOLDER"
    }
    $BASEFOLDER = -join($BASEFOLDER,"\",$PROJECTNAME)
    return $BASEFOLDER

}



#================================================================
# Build the project at specified place
# Takes path to folder where to create, and an iterable with everything

function Create-AllFolders
{   param(
        [string]$basefolder,
        $tablewithfolders)

    # Count folder number
    [int]$foldernumber = 0

    foreach ($folder in $allfolderstocreate )
    {
        if ($folder.Value )
        {
            #Append folder number at start, construct full path
            [string]$newfolder = -join("0",$foldernumber,"_",$folder.Value)
            [string]$newfolder = -join($BASEFOLDER,'\',$newfolder)

            # Say what we do, do it
            Write-Output "[CREATE] folder: $newfolder"
            New-Item -ItemType Directory -Path $newfolder

            # Next folder get next number
            [int]$foldernumber = $foldernumber + 1 
        }
    }



}




#================================================================
# Takes a directory
# Expands archives in it
# Rename all files with project code and orig
function Rename-Source
{
    param([string]$path,
            [string]$projectcode,
            [string]$orig)

    # Rename each file with code and "_orig"
    # Ignore structure folders
    foreach ($file in (Get-ChildItem -Path $path -Exclude "^[0-9][0-9]_" ))
    {
        $newname = -join($projectcode,"_",$file.BaseName,$orig,$file.Extension)
        Write-Output "[RENAME] As $newname"
        Rename-Item -Path $file.FullName -Newname "$newname"

    } # End of loop processing all source file


}




#================================================================
# Send a notification. Yes, im used to Linux
# Take title and text
function Notify-Send
{
    param(
        [string]$title,
        [string]$text)
    
    Write-Output "[INFO] Notify $title $text"
    $objNotifyIcon                          = New-Object System.Windows.Forms.NotifyIcon
    $objNotifyIcon.Icon                     = $icon
    $objNotifyIcon.BalloonTipTitle          = $title
    $objNotifyIcon.BalloonTipIcon           = "Info"
    $objNotifyIcon.BalloonTipText           = $text
    $objNotifyIcon.Visible                  = $True
    $objNotifyIcon.ShowBalloonTip(10000)

    $objNotifyIcon.Visible                  = $False
    $objNotifyIcon.Icon.Dispose();
    $objNotifyIcon.Dispose();

}




#================================================================
# Add a folder to File Explorer QuickAccess
# Takes a path to a folder
function Create-QuickAccess
{
    param([string]$folder)
    Write-Output "[CREATE] Shortcut in File explorer"
    $o = new-object -com shell.application
    $o.Namespace($folder).Self.InvokeVerb("pintohome")
}




#================================================================
function Start-TradosProject
{
    param([string]$projectname)

	Write-Output "Starting Trados Studio..."
    # May not be where expected
    try {
        Set-Location "C:\Program Files (x86)\Trados\Trados Studio\Studio17"
        }
    catch { 
        $TRADOSDIR = (Get-ChildItem -Path "C:\Program Files (x86)" -Filter *.sdlproj -Recurse -ErrorAction SilentlyContinue -Force -File).Directory.FullName
        Write-Output "[DETECTED] Trados in $TRADOSDIR"
        Set-Location $TRADOSDIR
        }

    .\SDLTradosStudio.exe /createProject /name $projectname

}