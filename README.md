# Helium

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Helium is a dnsmasq installer autoscript. Helium will setup dnsmasq to block porn, torrent, ads, tracker, malware, phishing and many more. Test Helium efficiency at [d3ward](https://d3ward.github.io/toolz/adblock.html).

<p align="center">
  <img src="d3ward2.png">
</p>

### Friendly CLI

It helps you manage dnsmasq configuration by simply following the on-screen instructions as easy as 1, 2, 3.

<p align="center">
  <img src="menu2.png">
</p>

### Requirement

Debian/Ubuntu server with Xray VPN (Vmess/Vless/Trojan) already installed.

If you don't have Xray VPN server yet, get [Silk Road](https://github.com/abidarwish/silkroad) which integrates Helium and many other features for a great VPN server.

Use this referral code and get €25 free credit to deploy a fresh Ubuntu server to install [Silk Road](https://github.com/abidarwish/silkroad):
https://upcloud.com/signup/?promo=7J3Z69

For premium technical support, please contact [Abi Darwish](https://t.me/abidarwish).

### How To Install

To install, SSH into your machine and run this command:

```
rm -rf /usr/local/sbin/helium && wget -q -O /usr/local/sbin/helium https://raw.githubusercontent.com/abidarwish/helium/main/helium.sh && chmod +x /usr/local/sbin/helium && helium
```
