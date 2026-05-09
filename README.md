Dropbear SSH Backport to Old Linux
==================================
From the original author:
A smallish SSH server and client
https://matt.ucc.asn.au/dropbear/dropbear.html

About This Backport
-------------------

This backport has been statically compiled and tested on RedHat 5.2 (1998). Since this uses C89 standards and syntax, in theory it *should* work on many other systems as well.

When completed, the following executables will be provided:

* `dropbear`
	* ssh server
* `dbclient`
	* ssh client
* `dropbearkey`
	* rsa, ecdsa, and ed25519 key generation
* `scp` or `dbscp` (if scp already exists on the system)
	* file transfer over ssh

Instructions
------------

### Step 1: Compile

```
cd backport
./dropbear-compile.sh
```

You *have* to be in the backport folder when running the compile script so that `$(pwd)` checks out. Old versions of bash do not play nice when trying to find the absolute directory of the script.

If your target machine is too old to download this code to compile it (most likely due to lack of HTTPS support, or the use of older versions of ftp/rsync/etc.. protocols), you can host it on your local network with a plain http server and download it on the old client with wget:

```
cd dropbear-backport
python3 -m http.server 8000 &
```

### Step 2: Install

```
cd backport
./dropbear-install.sh
```

The installer will copy the executables to `/usr/sbin` and `/usr/bin` and generate the host keys for the ssh server. If the local system uses sysvinit then it will also create an init script.

You can then start the server and verify it immediately with:

```
/etc/rc.d/init.d/dropbear start
/etc/rc.d/init.d/dropbear status
chkconfig --list dropbear
```

Edit the init script to change the port that the server runs on.

Contributing
------------

All of the modifications/patches can be found in the backport/ directory.

You can try applying the patches to newer versions of dropbear as they are released, or you can modify the patches to work on additional systems.

All modifications to the code must be put into the `backport/` folder so that the port can be re-applied to different versions of dropbear as needed, or to create different ports for different target systems. No direct changes to the codebase will be accepted.

License
-------

The license for the backport code is in the `backport/` folder. Dropbear
