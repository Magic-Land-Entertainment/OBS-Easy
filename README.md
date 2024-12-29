# OBS-Easy

Install OBS, plugins, and tools, easily to simplify the setup of streaming integration to larger audio/video environments

## Available options

- Install into Distrobox container
- Install into running OS
- Install and configure DistroAV plugin for NDI support
- Appliance mode - Install and configure fluxbox, pulseaudio for minimal appliance like environment and operation (Beta)

## Currently supported Distros

- Steamdeck - Distrobox install only
- Linux Mint 22

## Known issues

- Nvidia hardware acelleration support not working in distrobox containers
- NDI devices on the network tend to show up twice, does not appear to impact functionality

## TODO

- Further testing on Linux Mint 22 especially for appliance mode
- Test on Ubuntu 24.04
- Add more OS testing to ensure the current system is supported
- Improve appliance mode with more automation and better menu options
- Set fluxbox default theme and other fluxbox configs

## Roadmap

- Support aes67-daemon in order to allow integration with Dante and REVENNA audio networks
- Support additional Distros
- Bootable USB Drive for non-destructive use of additional hardware

