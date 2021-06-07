#!/bin/bash
SGX_INSTALL_DIR=/opt/intel
GIT_CLONE_PATH=/tmp/sgx
GIT_CLONE_SGX_CTK=$GIT_CLONE_PATH/crypto-api-toolkit
CTK_REPO="https://github.com/intel/crypto-api-toolkit.git"
CTK_INSTALL=$SGX_INSTALL_DIR/cryptoapitoolkit
P11_KIT_PATH=/usr/include/p11-kit-1/p11-kit/

install_cryptoapitoolkit()
{
	pushd $PWD
	mkdir -p $GIT_CLONE_PATH
        rm -rf $GIT_CLONE_SGX_CTK
        git clone $CTK_REPO $GIT_CLONE_SGX_CTK || exit 1
        cd $GIT_CLONE_SGX_CTK
	sed  's/16/32/' -i src/p11/trusted/SoftHSMv2/common/QuoteGenerationDefs.h 
        bash autogen.sh || exit 1
        ./configure --with-p11-kit-path=$P11_KIT_PATH --prefix=$CTK_INSTALL --enable-dcap || exit 1
	make install || exit 1
	popd
}

check_prerequisites()
{
        if [ ! -f /opt/intel/sgxsdk/bin/x64/sgx_edger8r ];then
                echo "sgx sdk is required for building cryptokit."
                exit 1
        fi
}

check_prerequisites
install_cryptoapitoolkit
