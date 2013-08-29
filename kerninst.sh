#!/bin/sh

. /etc/init.d/functions.sh
. /etc/kerninst/kerninst.conf

LOGFILE=/var/log/kerninst.log

/bin/rm -f "${LOGFILE}"

if [ ! -L /usr/src/linux ]; then
    eerror "The symbolic link /usr/src/linux does not exits."
    exit 1
fi

KERNEL_DIR=$(readlink /usr/src/linux)

if [ ! -d "/usr/src/${KERNEL_DIR}" -o ! -f "/usr/src/${KERNEL_DIR}/Makefile" ]; then
    if [ ! grep -q KBUILD "/usr/src/${KERNEL_DIR}/Makefile" ]; then
        eerror "The file /usr/src/${KERNEL_DIR} is not a valid kernel directory."
        exit 1
    fi
fi

KERNEL_VERSION=$(readlink /usr/src/linux | sed "s/^linux-//g")

function die() {
    eerror "An error ocurred. Exiting."
    exit 1
}

function kernel_compile() {
    einfo "Copying kernel configuration from ${KERNEL_CONFIG}..."
    /bin/cp -f "${KERNEL_CONFIG}" /usr/src/linux/.config &>> "${LOGFILE}" || die

    einfo "Configuring kernel..."
    /bin/yes "" | make -C /usr/src/linux oldconfig &>> "${LOGFILE}" || die

    if [ "${UPDATE_KERNEL_CONFIG}" == "yes" ]; then
        einfo "Updating kernel config..."
        /bin/cp -f /usr/src/linux/.config "${KERNEL_CONFIG}" || die
    fi

    einfo "Compiling kernel..."
    /usr/bin/make ${KERNEL_MAKEOPTS} -C /usr/src/linux &>> "${LOGFILE}" || die
}

function kernel_install() {
    einfo "Deleting kernel files with version ${KERNEL_VERSION} from /boot and /lib/modules..."
    /bin/rm -f "/boot/config-${KERNEL_VERSION}" &>> "${LOGFILE}" || die
    /bin/rm -f "/boot/initrd-${KERNEL_VERSION}" &>> "${LOGFILE}" || die
    /bin/rm -f "/boot/System.map-${KERNEL_VERSION}" &>> "${LOGFILE}" || die
    /bin/rm -f "/boot/vmlinuz-${KERNEL_VERSION}" &>> "${LOGFILE}" || die
    /bin/rm -rf "/lib/modules/${KERNEL_VERSION}" &>> "${LOGFILE}" || die

    einfo "Installing kernel..."
    make -C /usr/src/linux install &>> "${LOGFILE}" || die

    einfo "Installing modules..."
    make -C /usr/src/linux modules_install &>> "${LOGFILE}" || die
}

function make_initrd() {
    if [ "${MODULES_REBUILD}" == "yes" ]; then
        einfo "Recompiling modules..."
        /usr/bin/emerge -v @module-rebuild &>> "${LOGFILE}" || die
    fi

    einfo "Creating initrd for kernel version ${KERNEL_VERSION}..."
    if [ "${INCLUDE_FIRMWARE}" == "yes" ]; then
        FIRMWARE="-I"
        for i in $(find /lib64/firmware -type f); do
            FIRMWARE+=" ${i}"
        done
        /usr/bin/dracut -f -H "${FIRMWARE}" /boot/initrd-${KERNEL_VERSION} ${KERNEL_VERSION} &>> "${LOGFILE}" || die
    else
        /usr/bin/dracut -f -H /boot/initrd-${KERNEL_VERSION} ${KERNEL_VERSION} &>> "${LOGFILE}" || die
    fi
    einfo "The initrd was saved in /boot/initrd-${KERNEL_VERSION}."
}

function update_grub2() {
    /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg &>> "${LOGFILE}" || die
}

function update_grub() {
    einfo "Generating /boot/grub/grub.conf..."
    KERNELS=$(find /boot -name "vmlinuz*" | sort -r)

    echo "${GRUB_HEADER}" > /boot/grub/grub.conf || die

    for KERNEL in ${KERNELS}; do
        cat << EOF >> /boot/grub/grub.conf

title ${GRUB_KERNEL_TITLE} (kernel ${KERNEL_VERSION})
root ${GRUB_ROOT_PARTITION}
kernel ${KERNEL} root=${ROOT_PARTITION} init=${INIT} ${INIT_OPTIONS}
EOF

        einfo "Added ${KERNEL} kernel."

        if [ -f "/boot/initrd-${KERNEL_VERSION}" ]; then
            echo "initrd /boot/initrd-${KERNEL_VERSION}" > /boot/grub/grub.conf || die
            einfo "Added /boot/initrd-${KERNEL_VERSION} initramfs."
        fi
    done
}

function update_bootmanager() {
    einfo "Updating ${BOOTMANAGER}..."
    case "${BOOTMANAGER}" in
        GRUB)
            update_grub
            ;;
        GRUB2)
            update_grub2
            ;;
        *)
            ewarn "Invalid bootmanager ${BOOTMANAGER}."
    esac
}

EXEC_NAME=$(/usr/bin/basename "$0")

for ARG in "$@"; do
    case "${ARG}" in
        --no-modules)
            MODULES_REBUILD="no"
            ;;
    esac
done

case "${EXEC_NAME}" in
    kerninst)
        kernel_compile
        kernel_install
        make_initrd
        update_bootmanager
        ;;
    kerninst-compile)
        kernel_compile
        ;;
    kerninst-install)
        kernel_install
        ;;
    kerninst-mkinitrd)
        make_initrd
        ;;
    kerninst-updatebm)
        update_bootmanager
        ;;
    *)
        eerror "Invalid executable name."
        ;;
esac
