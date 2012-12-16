# glacier_backup

Conduct personal backups to Amazon's Glacier service. The task is made vastly
simpler due to Amazon's bridge between S3 and Glacier by way of transition
policies.

In other words, you can copy files to an S3 bucket which then transitions the
files automatically to Glacier behind the scenes. It is much easier than using
Glacier directly, which requires you to keep record of backup metadata (i.e.
which file is located in which archive).

## Setup
* Use the .rvmrc file and then ```bundle install```
* Copy the ```config.yml.example``` to ```$HOME/.glacierbackup.yml```
* Add the following to the config file:
 * Desired directories to backup
 * AWS keypair
 * Bucket used for backup location

An sqlite database will be created in ```$HOME/.glacierbackup.sqlite```
automatically.

### Bucket Naming
*Please note!* S3 bucket names must be globally unique. This program will
verify that your configured bucket exists and will attempt to create it
if it is not yet present. There is of course the chance that the bucket
will exist and you didn't create it. This program will verify that you are
the owner of the bucket before attempting to use it.

## Running
* Just run the ```glacier_backup.rb``` script. It will print runtime
information.
