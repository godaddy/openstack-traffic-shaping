#!/usr/bin/env python
# 8/12/2015 - Jim Gorz <jgorz@godaddy.com>
# IFB SWEEPER for Hypervisors, matches ifb names to tap devices and removes ifbs that don't have a tap device
#

import sys
import subprocess
import syslog

IFBS=[]
TAPS=[]

def call(args):
  """ Wrap system calls so that they are logged first
  """
  #syslog.syslog("About to execute %s " % ' '.join(args))
  subprocess.check_call(args, stderr=subprocess.STDOUT)

def read_interfaces(filename):
  with open(filename, 'r') as f:
    # replace whitespace with nothing for formatting
    data = f.read().replace("  ","")
# http://stackoverflow.com/questions/7630273/convert-multiline-into-list
  return [y for y in (x.strip() for x in data.splitlines()) if y]

def update_globals():
  for line in range(len(rawdata)):
#  intf = line[:line.index(":")].strip()
    if "tap" in rawdata[line][:3]:
#    print ("%s intf is a tap!" % rawdata[line][:14])
      TAPS.append(rawdata[line][:14])
    if "ifb" in rawdata[line][:3]:
#    print ("%s ifb device found!" % rawdata[line][:14])
      IFBS.append(rawdata[line][:14])

def get_orphans():
  orphans = []
  for ifb in IFBS:
    if "tap"+ifb[3:] not in TAPS:
#      print ("%s is an orphan" % ifb)
      orphans.append(ifb)
  return orphans

rawdata = read_interfaces('/proc/net/dev')
update_globals()
orph = get_orphans()

if len(orph) > 0:
  for device in orph:
    commands = [
      ['/sbin/ip', 'link', 'del', 'dev', device, ],
    ]
    for cmd in commands:
      try:
        call(cmd)
      except subprocess.CalledProcessError as e:
        syslog.syslog("ifbsweeper:  Unable to clean orphaned ifb device: %s" % orph)
        syslog.syslog("Output: %s" % e.output)

