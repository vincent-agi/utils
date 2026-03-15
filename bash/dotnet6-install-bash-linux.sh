#!/bin/bash
echo "dotnet package from microsoft download"
wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
echo "install pakage PPA microsoft"
sudo dpkg -i packages-microsoft-prod.deb

echo "system update"
sudo apt-get update -y
sudo apt-get install apt-transport-https dotnet-sdk-6.0 dotnet-runtime-6.0 -y

echo "check if dotnet if well installed"
echo "please check dotnet version"
dotnet --version