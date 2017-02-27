f5-bigip Cookbook CHANGELOG
==============================
This file is used to list changes made in each version of the f5-bigip cookbook.

v0.5.7
------
* Rubocop style cleanup

v0.5.6
------
* Bug - irule variables hash defaults to an empty array

v0.5.5
------
* Bug - translate address current value overwritten by translate port value
* Bug - always compares irules against nil
* Bug - fails to create node if existing node already using address

v0.5.3
------
* Support removing pool members
* Set username and password for monitors (sets password on every run, because encryption)

v0.5.2
------
* Remove subdirs in libraries folder (#9)

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
