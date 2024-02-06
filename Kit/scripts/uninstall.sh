#! /bin/sh

sudo launchctl unload /Library/LaunchDaemons/eu.exelban.Stats.SMC.Helper.plist
sudo rm /Library/LaunchDaemons/eu.exelban.Stats.SMC.Helper.plist
sudo rm /Library/PrivilegedHelperTools/eu.exelban.Stats.SMC.Helper
sudo rm $HOME/Library/Application Support/Stats
