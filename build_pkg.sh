#!/bin/zsh

IDENTIFIER="com.syncpool.pss-vm-app-updater"
IDENTITY="Developer ID Installer: Raell Dottin (DHJQ7QC53Z)"
VERSION="$(date "+%m.%d.%Y.%H.%M.%S")"
ACTIVE_USER=""
CAFFEINATEPID=""
PARENT_DIR=""

get_active_user() {
    #       Collect current logged in user
    ACTIVE_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
}

print_log() {
    #	Print a log message to standard output and a log file
    message="${*}"
    timestamp=$(date -u +%F\ %T)

    get_active_user
    if [[ "${message}" == "${previous_message}" ]]; then
        ((logrepeat = logrepeat + 1))
        return
    fi
    previous_message="${message}"
    if [[ $logrepeat -gt 1 ]]; then
        echo "${timestamp}:${ACTIVE_USER}[$$] : Last message repeated {$logrepeat} times"
        logger -i "Last message repeated {$logrepeat} times"
        logrepeat=0
    fi
    echo "${timestamp}:${ACTIVE_USER}[$$] : ${message}"
    logger -i "$message"
}

usage() {
    get_parent_directory
    get_active_user
    if [[ "$(id -u)" != "0" ]]; then
        print_log "Please run this script as root"
        exit 1
    elif [[ -z "$1" ]]; then
        echo "Usage: $(basename "${0}") [package name]"
        exit 1
    elif [[ -z "${PARENT_DIR}" ]]; then
        print_log "No parent directory specified"
        exit 1
    elif [[ -z "${IDENTIFIER}" ]]; then
        print_log "No identifier specified"
        exit 1
    elif [[ -z "${VERSION}" ]]; then
        print_log "No version specified"
        exit 1
    elif [[ -z "${ACTIVE_USER}" ]]; then
        print_log "No active user found"
        exit 1
    fi
}

start_caffeinate() {
    caffeinate -d -i -m -u &
    CAFFEINATEPID=${!}
    print_log "Started the caffeinate process: pid ${CAFFEINATEPID}"
}

runas_active_user() {
    get_active_user
    launchctl "asuser" "$(id -u "${ACTIVE_USER}")" sudo -iu "${ACTIVE_USER}" "$@"
    print_log "Running \"${*}\" as ${ACTIVE_USER}"
}

get_parent_directory() {
    PARENT_DIR=$(unset CDPATH && cd "$(dirname "$0")" && echo "$PWD")
    print_log "Parent directory: ${PARENT_DIR}"
}

add_external_variables() {
    print_log "Adding external variables to $PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"

    REMOTE_HOST=$(cat "${PARENT_DIR}/.env/REMOTE_HOST")
    echo -n "Value: "
    echo "\"${PARENT_DIR}/.env/REMOTE_HOST:REMOTE_HOST=$REMOTE_HOST\""
    echo -n "Before change: "
    grep -HE "^REMOTE_HOST=.*$" "$PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"
    sed -i '' "s/^REMOTE_HOST.*$/REMOTE_HOST\=\"$REMOTE_HOST\"/" "$PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"
    echo -n "After change: "
    grep -HE "^REMOTE_HOST=.*$" "$PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"

    REMOTE_USER=$(cat "${PARENT_DIR}/.env/REMOTE_USER")
    echo -n "Value: "
    echo "\"${PARENT_DIR}/.env/REMOTE_USER:REMOTE_USER=$REMOTE_USER\""
    echo -n "Before change: "
    grep -HE "^REMOTE_USER=.*$" "$PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"
    sed -i '' "s/^REMOTE_USER.*$/REMOTE_USER\=\"$REMOTE_USER\"/" "$PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"
    echo -n "After change: "
    grep -HE "^REMOTE_USER=.*$" "$PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"
}

pre_packaging() {
    print_log "Applying file and directory permissions before packaging"
    if [[ ! -d "${PARENT_DIR}/payload" ]]; then
        print_log "No payload directory found"
        exit 1
    fi
    if [[ -d "${PARENT_DIR}/payload" ]]; then
        sudo chown -R root:wheel "${PARENT_DIR}/payload"
        sudo chmod -R 755 "${PARENT_DIR}/payload"
        /bin/chmod -R o+r "${PARENT_DIR}/payload/"
    fi
    if [[ -d "${PARENT_DIR}/scripts" ]]; then
        sudo chown -R root:wheel "${PARENT_DIR}/scripts"
        sudo chmod -R 755 "${PARENT_DIR}/scripts"
        /bin/chmod +x "${PARENT_DIR}/scripts"
    fi

    if [[ ! -d "${PARENT_DIR}/build" ]]; then
        /bin/mkdir "${PARENT_DIR}/build"
    fi
    sudo chmod 644 "${PARENT_DIR}"/payload/Library/LaunchDaemons/*.plist
    get_active_user
    sudo /usr/sbin/chown "${ACTIVE_USER}":admin "${PARENT_DIR}/build"

    /usr/bin/find "${PARENT_DIR}" -name .DS_Store -delete
    sudo xattr -d -r com.apple.quarantine "${PARENT_DIR}"/payload

}

post_packaging() {
    print_log "Applying file and directory permissions post packaging"
    get_active_user
    chown -R "${ACTIVE_USER}" "${PARENT_DIR}/payload" "${PARENT_DIR}/scripts"
}

remove_external_variables() {
    print_log "Removing external variables to $PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"

    REMOTE_HOST=$(cat "${PARENT_DIR}/.env/REMOTE_HOST")
    echo -n "Before change: "
    grep -HE "^REMOTE_HOST=.*$" "$PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"
    sed -i '' "s/^REMOTE_HOST.*$/REMOTE_HOST\=/" "$PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"
    echo -n "After change: "
    grep -HE "^REMOTE_HOST=.*$" "$PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"

    REMOTE_USER=$(cat "${PARENT_DIR}/.env/REMOTE_USER")
    echo -n "Before change: "
    grep -HE "^REMOTE_USER=.*$" "$PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"
    sed -i '' "s/^REMOTE_USER.*$/REMOTE_USER\=/" "$PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"
    echo -n "After change: "
    grep -HE "^REMOTE_USER=.*$" "$PARENT_DIR/payload/Library/Application Support/com.syncpool.app-downloader/app-downloader.sh"
}

create_component_plist() {
    print_log "Creating the component plist"
    if ! /usr/bin/pkgbuild \
        --analyze \
        --root "${PARENT_DIR}/payload" \
        --identifier "${IDENTIFIER}" \
        --version "${VERSION}" \
        --install-location "/" \
        "${PARENT_DIR}/build/$1-${VERSION}.plist"; then
        print_log "Failed to create the component plist"
        exit 1
    fi

}

build_package() {
    print_log "Building the component package"
    echo "Payload Directory: ${PARENT_DIR}/payload"
    echo "Scripts Directory: ${PARENT_DIR}/scripts"
    echo "Package Identifier: ${IDENTIFIER}"
    echo "Package Version: ${VERSION}"
    echo "Component Package Path: ${PARENT_DIR}/build/$1-${VERSION}-component.pkg"
    if ! /usr/bin/pkgbuild \
        --root "${PARENT_DIR}/payload" \
        --component-plist "${PARENT_DIR}/build/$1-${VERSION}.plist" \
        --scripts "${PARENT_DIR}/scripts" \
        --identifier "${IDENTIFIER}" \
        --version "${VERSION}" \
        --install-location "/" \
        "${PARENT_DIR}/build/$1-${VERSION}-component.pkg"; then
        print_log "Failed to build the package"
        exit 1
    fi
}

create_distribution_plist() {
    print_log "Creating a distribution plist"
    if ! /usr/bin/productbuild \
        --synthesize \
        --product "${PARENT_DIR}/resources/requirements.plist" \
        --package "${PARENT_DIR}/build/$1-${VERSION}-component.pkg" \
        "${PARENT_DIR}/build/$1-${VERSION}-distribution.plist"; then
        print_log "Failed to create the distribution plist"
        exit 1
    fi
}

create_product_archive() {
    print_log "Creating the Product Archive"
    if ! /usr/bin/productbuild \
        --distribution "${PARENT_DIR}/build/$1-${VERSION}-distribution.plist" \
        --package-path "${PARENT_DIR}/build" \
        "${PARENT_DIR}/build/$1-${VERSION}.pkg"; then
        print_log "Failed to create the product archive"
        exit 1
    fi
}

signed_package() {
    if ! runas_active_user "productsign" "--sign" "$IDENTITY" "${PARENT_DIR}/build/${1}-${VERSION}.pkg" "${PARENT_DIR}/build/${1}-signed-${VERSION}.pkg"; then
        print_log "Failed to sign the package"
        exit 1
    else
        if [[ -f "${PARENT_DIR}/build/${1}-signed-${VERSION}.pkg" ]]; then
            print_log "Signed package created: ${PARENT_DIR}/build/${1}-signed-${VERSION}.pkg"
        fi
    fi
}

how_to_install_remotely() {
        print_log "Copy the package on a macOS remote host: scp \"${PARENT_DIR}/build/${1}-signed-${VERSION}.pkg\" REMOTE_USER@REMOTE_HOST:\"REMOTE_DIRECTORY\""
        print_log "Install the package on a macOS remote host: ssh -t rdottin@REMOTE_HOST sudo installer -pkg \"/Users/rdottin/${1}-signed-${VERSION}.pkg\" -target /"
}

clean_up() {
    if [[ -n "${CAFFEINATEPID}" ]]; then
        print_log "Stopped the caffeinate process: pid ${CAFFEINATEPID}"
        kill "${CAFFEINATEPID}"
    fi
}


main() {
    trap clean_up EXIT
    get_parent_directory
    usage "${1}" "${2}"
    start_caffeinate
    pre_packaging
    add_external_variables
    create_component_plist "${1}"
    build_package "${1}"
    create_distribution_plist "${1}"
    create_product_archive "${1}"
    signed_package "${1}"
    post_packaging
    remove_external_variables
    how_to_install_remotely "${1}"
}

if [[ "${(%):-%N}" == "$0" ]]; then
    main "${1}" "${2}"
fi
