Dropbear SSH Backport to Old Linux
==================================
A smallish SSH server and client, ported for vintage x86 CPUs & Linux Kernels.

Read about Dropbear from the original author:

https://matt.ucc.asn.au/dropbear/dropbear.html

About This Backport
-------------------

This backport has been tested to statically compile and build on RedHat 5.2 (1998)
using i386, i486, i586, and i686 CPUs. In theory it *should* work on any Linux 2.x
kernel or later, and it includes an init script for systems which use SysVinit.

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

With the backport script provided, dropbear has been tested to compile and run on RedHat 5.2,
on various CPUs from a 386sx to a Pentium III, on physical hardware and in 86box,
with the following package versions:
* gcc-2.7.2.3-14
* libc-5.3.12-27
* make-3.76.1-5
* kernel-2.0.36-0.7
* kernel-headers-2.0.36-0.7

The required zlib, libtomcrypt, and libtommath dependencies are included in this repo.

Since this toolchain uses C89 syntax (no C99 compatibility), in theory it should be compilable
on any version of Linux, vintage or modern. Feel free to try and report back.

****SECURITY NOTICE:**** _The post-quantum KEX algorithms in dropbear use assembly code that
isn't compatible with older CPUs. Rather than re-writing this code, I have chosen to simply
disable it. Keep that in mind if quantum-safe security is a concern for you._

```
cd backport

# For i386 and later 32-bit architectures.
# This avoids using CPU instructions which did not exist on the 386
# such as **bswap**, and skips all inline assembly.
./dropbear-compile.sh -386

# For i486, i586, and i686 architectures.
# Takes advantage of inline assembly and newer instructions to run faster.
./dropbear-compile.sh -486
```

As a side note, if you need a convenient way to transfer this repo or to an older system
which doesn't support SSH or TLS1.2/1.3, an easy workaround is to tar.gz the repo with an
older format and serve it on a plain HTTP server. Old systems can then retrieve it with `wget`.

```
# On modern system
tar --format=ustar -zcpf dropbear-backport.tar.gz dropbear-backport
python3 -m http.server 8000

# On old system
wget http://$HOSTIP:8000/dropbear-backport.tar.gz
tar -zxpf dropbear-backport.tar.gz
```

### Step 2: Install

```
cd dropbear-backport/backport
./dropbear-install.sh
```

The installer will do the following:

* Copy the binaries to `/usr/sbin` and `/usr/bin`
* Generate the host keys for the ssh server at `/etc/dropbear`
* Install an init.d script at `/etc/rc.d/init.d/dropbear` for systems which use SysVinit
	* The dropbear daemon will run at boot. Disable it with `chkconfig` or by unlinking the script at the various runlevels manually.
* Add an entry in `/etc/services` for SSH on port 22 if no other service is specified there yet (on systems which use it).

If your system uses SysVinit, you can then start the server and verify it immediately with:

```
/etc/rc.d/init.d/dropbear start
/etc/rc.d/init.d/dropbear status
chkconfig --list dropbear
```

Edit the init script to change the port that the server runs on.

### Usage Notes

#### SSH Daemon Options

Dropbear sets options for the daemon (such ass permitting root logins or password logins) through command-line parameters. There's
a field at the top of the init.d script which lets you customize these parameters for your setup. Run `dropbear --help` for a list
of all of the supported flags.

The installer will set the flags as: `DROPBEAR_FLAGS="-w -p 0.0.0.0:22"`, which disables root login and listens on port 22 on all
interfaces. Use `-s` to disable all password logins.

#### Host Keys

The default locations for dropbear's host keys are in `/etc/dropbear`. You can use the init script to easily generate/rotate them.

```
# Generate missing keys
/etc/rc.d/init.d/dropbear create_host_keys

# Delete and re-generate all keys
/etc/rc.d/init.d/dropbear create_host_keys --force
```

#### SCP

To scp a file from a modern system, the `-O` flag must be passed to use the legacy scp protocol.

```
scp -O -i ~/.ssh/id_ed25519 ./local_file user@system:~/
```

Contributing
------------

All of the modifications/patches can be found in the backport/ directory. The main codebase has not been changed directly, and instead is patched by the script `backport-code-patch.sh` when compiling.

You can try applying the patches to newer versions of dropbear as they are released, or you can modify the patches to work on additional systems.

All patches to the code must be put into the file `backport/backport-code-patch.sh`. If a patch is large, put it in the `backport/patches/` folder, and call it from the script instead. Each patch must be idempotent, meaning no matter how many times it is run it will only patch the code once so as not to break things. No direct changes to the Dropbear codebase will be accepted in PRs.

License
-------

The license for the backport code is in the `backport/` folder. Dropbear has it's own license included in the root of this repo.
