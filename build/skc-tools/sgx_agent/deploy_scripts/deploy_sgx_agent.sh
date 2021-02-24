#!/bin/bash
SGX_DRIVER_VERSION=1.41
KDIR=/lib/modules/$(uname -r)/build
SGX_INSTALL_DIR=/opt/intel
MP_RPM_VER=1.10.100.4-1
SGX_AGENT_BIN=bin

cat $KDIR/.config | grep "CONFIG_INTEL_SGX=y" > /dev/null
INKERNEL_SGX=$?
/sbin/modinfo intel_sgx &> /dev/null
SGX_DRIVER_INSTALLED=$?

# Check OS and VERSION
OS=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
temp="${OS%\"}"
temp="${temp#\"}"
OS="$temp"
VER=$(cat /etc/os-release | grep ^VERSION_ID | tr -d 'VERSION_ID="')
OS_FLAVOUR="$OS""$VER"

install_prerequisites()
{
        source deployment_prerequisites.sh
        if [[ $? -ne 0 ]]; then
                echo "sgx agent pre-requisite package installation failed. exiting"
                exit 1
        fi
}

install_dcap_driver()
{
	chmod u+x $SGX_AGENT_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin
	echo "$INKERNEL_SGX"
	echo "$SGX_DRIVER_INSTALLED"
	if [[ "$INKERNEL_SGX" -eq 1 && "$SGX_DRIVER_INSTALLED" -eq 1 ]]; then
		./$SGX_AGENT_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin -prefix=$SGX_INSTALL_DIR || exit 1
		echo "sgx dcap driver installed"
	else
		echo "found inbuilt sgx driver, skipping dcap driver installation"
	fi
}

install_psw_qgl()
{
	if [ "$OS" == "rhel" ]; then
		tar -xf $SGX_AGENT_BIN/sgx_rpm_local_repo.tgz
		yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo
		yum-config-manager --save --setopt=tmp_sgx_sgx_rpm_local_repo.gpgcheck=0
		dnf install -qy --nogpgcheck libsgx-dcap-ql || exit 1
		rm -rf sgx_rpm_local_repo /etc/yum.repos.d/*sgx_rpm_local_repo.repo
	elif [ "$OS" == "ubuntu" ]; then
		echo 'deb [arch=amd64] https://download.01.org/intel-sgx/sgx_repo/ubuntu/ bionic main' | sudo tee /etc/apt/sources.list.d/intel-sgx.list
		wget -qO - https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | sudo apt-key add -
		apt update
		apt install -y libsgx-dcap-ql || exit 1
	fi
}
	
install_multipackage_agent_rpm()
{
	if [ "$OS" == "rhel" ]; then
		rpm -ivh $SGX_AGENT_BIN/libsgx-ra-uefi-$MP_RPM_VER.el8.x86_64.rpm
	elif [ "$OS" == "ubuntu" ]; then
		apt install -y libsgx-ra-uefi
	fi
}

install_pckretrieval_tool()
{
	\cp -pf $SGX_AGENT_BIN/libdcap_quoteprov.so.1 $SGX_AGENT_BIN/pck_id_retrieval_tool_enclave.signed.so /usr/sbin/
	\cp -pf $SGX_AGENT_BIN/PCKIDRetrievalTool /usr/sbin/
}

install_sgx_agent() { 
	\cp -pf sgx_agent.env ~/sgx_agent.env

	source agent.conf
	CMS_URL=https://$CMS_IP:8445/cms/v1
	AAS_URL=https://$AAS_IP:8444/aas
	SHVS_URL=https://$SHVS_IP:13000/sgx-hvs/v2
	SCS_URL=https://$SCS_IP:9000/scs/sgx
	sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/sgx_agent.env
	sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/sgx_agent.env
	sed -i "s@^\(SHVS_BASE_URL\s*=\s*\).*\$@\1$SHVS_URL@" ~/sgx_agent.env
	sed -i "s@^\(SCS_BASE_URL\s*=\s*\).*\$@\1$SCS_URL@" ~/sgx_agent.env
	sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SGX_AGENT_IP/" ~/sgx_agent.env
	sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/sgx_agent.env
	sed -i "s/^\(SGX_AGENT_USERNAME\s*=\s*\).*\$/\1$AGENT_USER/" ~/sgx_agent.env
	sed -i "s/^\(SGX_AGENT_PASSWORD\s*=\s*\).*\$/\1$AGENT_PASSWORD/" ~/sgx_agent.env

	sgx_agent uninstall --purge
	$SGX_AGENT_BIN/sgx_agent-v*.bin
	sgx_agent status > /dev/null
	if [ $? -ne 0 ]; then
		echo "SGX Agent Installation Failed"
		exit 1
	fi
	echo "SGX Agent Installation Successful"
}

install_prerequisites
install_dcap_driver
install_psw_qgl
install_multipackage_agent_rpm
install_pckretrieval_tool
install_sgx_agent
