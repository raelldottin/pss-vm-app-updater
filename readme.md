# PSS VM APP Updater
A method to synchronize app from a host system to multiple virtual machines
hosted on UTM.

# Setup Instructions:
Each virtual machine will need ssh keys of the host machine. You can generate
ssh keys using the following commands
- `ssh-keygen`
- (LEAVE THE PASSPHRASE EMPTY)
The following command will copy your ssh key to from the host machine to the
virtual machine, its required that you change the username to a username on the
virtual machine and remote_host to the host name or IP address of the virtual
machine
- `ssh-copy-id username@remote_host`

If you encounter any issues, file a issue in this repo or refer to
(Digital Ocean article)[https://www.digitalocean.com/community/tutorials/how-to-configure-ssh-key-based-authentication-on-a-linux-server] for additional assistance.
