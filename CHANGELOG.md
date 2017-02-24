f5-bigip Cookbook CHANGELOG
==============================
This file is used to list changes made in each version of the f5-bigip cookbook.

v0.5.5
------
* Bug - translate address current value overwritten by translate port value
* Bug - always compares irules against nil
* Bug - fails to create node if existing node already using address

v0.5.3
------
* Additional bits for hmh cookbook support

v0.5.1
------
* Bugfix: Load System.Inet interface (#7)

v0.5.0
------
* Add support for non-ip node name to f5_ltm_node

v0.4.1
------
* Uptick to re-upload to supermarket after encountering CHEF-672 which caused knife to upload with missing library files

v0.4.0
------
* Initial Release
