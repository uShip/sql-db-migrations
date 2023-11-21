#!/bin/bash

# Installing OpenSSL
wget https://www.openssl.org/source/openssl-1.1.1p.tar.gz -O openssl-1.1.1p.tar.gz
tar -zxvf openssl-1.1.1p.tar.gz
cd openssl-1.1.1p
./config
make
sudo make install
sudo ldconfig
