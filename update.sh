#!/bin/bash

echo "Hi, it is now $(date)" >> /home/epvoteadmin/cc_production/log.txt

cd /home/epvoteadmin/cc_production/
git add .
git commit -m "autocommit"
git push origin main
