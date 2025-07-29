#!/bin/bash

# This script sets up a virtual machine environment suitable for tdx tests present in the canonical repository.

set -ex

export no_proxy="127.0.0.1,localhost,linux*.intel.com,ubit*.intel.com"

setup_no_proxy() {
    proxy_env=$(grep -i proxy /etc/environment 2>/dev/null || true)
    if [[ "$proxy_env" =~ "no_proxy" ]]; then
        sed -i 's/no_proxy=.*/no_proxy="127.0.0.1,localhost,linux*.intel.com,ubit*.intel.com"/' /etc/environment
    else
        echo 'no_proxy="127.0.0.1,localhost,linux*.intel.com,ubit*.intel.com"' >> /etc/environment
    fi

    if [[ "$proxy_env" =~ "http_proxy" ]]; then
        sed -i 's/http_proxy=.*/http_proxy=http:\/\/proxy-dmz.intel.com:911/' /etc/environment
    fi
    
    if [[ "$proxy_env" =~ "https_proxy" ]]; then
        sed -i 's/https_proxy=.*/https_proxy=http:\/\/proxy-dmz.intel.com:912/' /etc/environment
    fi

    echo "Update proxy settings in /etc/environment."
}

update_ssh_config() {
    root_login=$(grep -i "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null || true)
    if [ -z "$root_login" ]; then
        sed -i 's/.*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
        systemctl restart sshd
        echo "Updated SSH configuration to allow root login."
    fi
}

update_dnf_config() {
    ssl_verify=$(grep -i ^sslverify /etc/dnf/dnf.conf 2>/dev/null || true)
    if [ -z "$ssl_verify" ]; then
        echo "sslverify=False" >> /etc/dnf/dnf.conf
        echo "Updated DNF configuration to disable SSL verification."
    else 
        sed -i 's/^sslverify.*/sslverify=False/' /etc/dnf/dnf.conf
        echo "Updated DNF configuration to disable SSL verification."
    fi
}

setup_attestation() {
    if [ ! -f /etc/tdx-attest.conf ]; then
        echo "port=4050" >> /etc/tdx-attest.conf
    fi

    echo "Installing TDX Attestation libraries..."
    mkdir -p /opt/intel
    cd /opt/intel
    cp /tmp/sgx_rpm_local_repo.tgz .
    tar -xvf sgx_rpm_local_repo.tgz
    yum-config-manager --add-repo file:///opt/intel/sgx_rpm_local_repo
    yum install -y --nogpgcheck --disablerepo="*" --enablerepo="opt_intel_sgx_rpm_local_repo" libtdx-attest libtdx-attest-devel
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root or with sudo."
        exit 1
    fi
}

if [ -f /root/SETUP_VM_SUCCESS ]; then
    echo "VM setup already completed. Skipping setup."
    exit 0
fi

check_root
setup_no_proxy
update_ssh_config
update_dnf_config
setup_attestation

touch /root/SETUP_VM_SUCCESS
echo "VM setup completed successfully!"