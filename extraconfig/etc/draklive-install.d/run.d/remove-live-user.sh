#!/bin/bash
#
# Removes live user
#

userdel -r live
/usr/sbin/plymouth-set-default-theme Mandriva-Rosa -R
/bin/systemctl enable cups.service
/bin/systemctl start cups.service