#!/bin/bash

echo "Hi, today is $(date)" >> /home/epvoteadmin/cc_production/test.txt

cd /home/epvoteadmin/cc_production/
git add .
git commit -m "autocommit"
git push origin main
