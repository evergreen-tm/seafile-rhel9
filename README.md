## Automate install and configuration of Seafile through docker on RHEL and friends
#### Tested on Rocky Linux 9.1 with "Server" installation profile


### What it does:
Installing and configuring Seafile through Docker automatically  
Select a drive partition to use for external storage  
Optionally install and start Tailscale to connect it to a tailnet

### What it will do soon:
Automatically configure timezone for server  
Not break if the partition is already in fstab and/or already mounted  
Not require a separate partition for data  
More!


### Note:
This script is incomplete, albeit working on a fresh install with a partition created, formatted, and unmounted for use with Seafile.  
My skills wih bash scripting are not up to par to say the least, so while it will probably work I make no promises of it being a quality piece of code.
