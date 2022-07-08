#!/bin/bash

# A quick prototype for automating software installs on macOS

# Usage: app-downloader.sh

# Script Requirements: bash, curl, hdiutil, pkill, rm, cp, chown, xattr, (root or admin privileges to copy the app bundle into the Application folder)

#Set command search path
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/libexec:/System/Library/CoreServices
export PATH
PKILL_BIN=/usr/bin/pkill
RM_BIN=/bin/rm
CHOWN_BIN=/usr/sbin/chown
XATTR_BIN=/usr/bin/xattr
LOGGER_BIN=/usr/bin/logger
SED_BIN=/usr/bin/sed

#Set sed options for BSD sed vs GNU sed
if echo "" | $SED_BIN -r "s/.*//" 2> /dev/null 1>&2; then
    SED_OPTS="-r"
else
    SED_OPTS="-E"
fi

# Global variables
appName="Pixel Starships.app"
appPath="/Applications/$appName"
installPath="/Applications"
tmpDir="$(mktemp -d 2> /dev/null || mktemp -d -t 'mytmpdir')"

# External variables
REMOTE_HOST=$(netstat -rnf inet | awk '{if($1=="default") print $2}')
REMOTE_USER=

PrintLog() {
    local message=$1
    # We can use logger to log to syslog then output the same message to standard out with UTC Timestamps.
    # logger only outputs at current timezone.

    $LOGGER_BIN -i "$message"
    echo "$(date -u):${whoami[$$]} $message"
}

CleanUpExit() {
    if [[ -d $tmpDir ]]; then
        PrintLog "Deleting directory: $tmpDir$appPath"
        $RM_BIN -fr "$tmpDir$appPath"
    fi
    PrintLog "Exiting..."
    exit 1

}

CheckForNetwork() {
    local test

    if [[ -z "${NETWORKUP:=}" ]]; then
        test=$(/sbin/ifconfig -a inet 2> /dev/null | $SED_BIN -n -e '/127.0.0.1/d' -e '/0.0.0.0/d' -e '/inet/p' | wc -l)
        if [[ "${test}" -gt 0 ]]; then
            PrintLog "Network is up."
        else
            PrintLog "Network is down."
            CleanUpExit
        fi
    fi
}

DownloadApp() {
    # Download the app from the remote host to a tmp directory
    scp "$REMOTE_USER@$REMOTE_HOST:$appPath" "$tmpDir"
    if [[ -d "$tmpDir$appPath" ]]; then
        PrintLog "$appName was successfully copied to $tmpDir"
    else
        PrintLog "Failed to copy $appName to $tmpDir"
        CleanUpExit
    fi
}

CheckAppVersion() {
    # Compares the version of the download app and installed app. If the app versions are the same, then the script exits cleanly
    if [[ ! -d "$appPath" ]]; then
        PrintLog "$appPath does not exists"
        CleanUpExit
    fi
    downloaded_app_version=$(defaults read "$tmpDir$appPath/Contents/Info.plist" CFBundleVersion)
    installed_app_version=$(defaults read "$appPath/Contents/Info.plist" CFBundleVersion)
    if [[ $downloaded_app_version == "$installed_app_version" ]]; then
        PrintLog "$appName version $installed_app_version is already installed."
        CleanUpExit
    fi
}

whoami=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
PrintLog "$whoami is currently logged in."
PrintLog "$(id -F) is currently executing $0"

if [[ $(whoami) != "root" ]]; then
    if groups "$(whoami)" | grep -q -w admin; then
        PrintLog "$(whoami) has administrative rights. Proceeding with installation."
    else
        PrintLog "$(whoami) does not have administrative privileges Proceeding with installation."
        CleanUpExit
    fi
fi

CheckForNetwork
DownloadApp
CheckAppVersion

# Let's check if the application is still running before terminating it, and confirm that the application actually quits
while [[ $(pgrep "$appName") ]]; do
    if $PKILL_BIN "$appName"; then
        PrintLog "Successfully terminated $appName."
    else
        PrintLog "Failed to terminate $appName"
    fi
    sleep 1
done

# Check if the app is already install, delete the previous version before installation
if [[ -d "$installPath/$appName" ]]; then
    PrintLog "Removing previous application installation."
    # Let's reconsider removing directories and copy the file over to /tmp in a timestamp directory
    if $RM_BIN -fr "$installPath/$appName"; then
        PrintLog "Successfully removed the prevous installation."
    else
        PrintLog "Failed to remove previous installation."
        CleanUpExit
    fi
fi

# Copy the new app version to the Application folder
if rsync -azq "$tmpDir" "$installPath/"; then
    PrintLog "Copied $appName to $installPath folder."
else
    PrintLog "Failed to copy $appName from $tmpDir to the /Applications folder."
    PrintLog "Please run this script as root or user in the admin group."
    CleanUpExit
fi

# Change permissions on the app bundle -- Note, the installation still need root access to install the app into the application folder.
if $CHOWN_BIN -R "$whoami":staff "$installPath/$appName"; then
    PrintLog "Providing $whoami with access to $installPath/$appName"
else
    PrintLog "Failed to provide $whoami with access to $installPath/$appName"
fi
# Remove quarantine flag, this might randomly return an error
if $XATTR_BIN -r -d com.apple.quarantine "$installPath/$appName"; then
    PrintLog "Removed quarantine flag on $appName"
else
    PrintLog "Unable to remove the quarantine flag on $appName"
fi

PrintLog "Installation Successful."
