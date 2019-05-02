#############################################################################
# Filename: diskUtilization.py
# Date Created: 03/27/19
# Author: Marco Tijbout
#
# Version 1.0
#
# Description: Provides the disk utilization as Percentage Metric.
#
# Usage: Store this script in /home/pi/scripts
#
# Version history:
# 1.1 - Marco Tijbout: Original Script.
#############################################################################
import shutil

(total, used, free) = shutil.disk_usage('/')
print ("%.0f" % (float(used)/float(total)*100))