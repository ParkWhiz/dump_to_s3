# Dump_to_S3

Script to dump database backups to S3 with rotation

## Requirements

- bash
- [AWS CLI](https://aws.amazon.com/cli/)

## Setup

After installing the AWS CLI, run 

```
aws configure
```

to set up the user running the script with AWS credentials. The AWS
credentials must be sufficiently powerful to list, put, get, and delete
objects in the S3 bucket that you wish to use.

After AWS is configured, create a configuration script:

```
cd path_to_dump_to_s3_repo
cp conf.bash.example conf.bash
```

Then, edit the `conf.bash` script to suit your own environment and requirements.

Particularly important are the variables:

* `BUCKET_NAME` which should be set to the name of your S3 bucket
* `KEY_PREFIX` which is the prefix of the keys that will be created.
  `KEY_PREFIX` *must not* contain any underscores
* `BACKUP_COMMAND` which is the command that will be run to make the backup.
  The command should create a single file, which should be named 
  `$DUMP_FILE_NAME`. Since the command will be run with eval, expansion of
  `$DUMP_FILE_NAME` should be deferred (by, for example, backslash escaping 
  the `$`). See `conf.bash.example` for an example command.

After editing `conf.bash`, you can add `dump_to_s3.bash` to crontab. The
script is intended to be run once an hour.

## Behavior

Every time it is invoked, `dump_to_s3.bash` will create a backup, upload the
backup to S3, and delete old backups in S3. Depending on the time it is 
invoked, the script may create a backup that is either hourly, daily, 
weekly, or monthy. The kind of backup affects the S3 key name and which old
backups are removed. The time of the day, week, or month that a daily, weekly,
or monthy backup is created can be configured in `conf.bash`. The keys are
named with the scheme:

```
"KEY_PREFIX"_"BACKUP_TYPE"_"TIMESTAMP"
```

where `BACKUP_TYPE` is `H` for hourly, `D` for daily, `W` for weekly or `M` for monthly
