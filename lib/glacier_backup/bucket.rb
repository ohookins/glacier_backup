require 'aws-sdk'

module GlacierBackup::Bucket
  RULE_ID = 'glacier-backup'
  TRANSITION_TIME = 0

  extend self

  def create(access_key, secret_key, bucket_name)
    s3 = AWS::S3.new(:access_key_id     => access_key,
                     :secret_access_key => secret_key
                    )

    bucket = s3.buckets[bucket_name]

    # Test for presence/ownership of the bucket
    if bucket.exists?
      begin
        bucket.acl
      rescue AWS::S3::Errors::AccessDenied
        STDERR.puts "Access Denied to S3 bucket '#{bucket_name}'. Do you own it?"
        exit(1)
      end
    else
      bucket = s3.buckets.create(bucket_name)
      puts "Created S3 bucket '#{bucket_name}'"
    end

    # Ensure the bucket lifecycle is set up correctly
    lifecycle = bucket.lifecycle_configuration
    lifecycle_setup(bucket) if lifecycle.rules.length == 1 and lifecycle.rules.first.id != RULE_ID
    lifecycle_setup(bucket) if lifecycle.rules.length != 1

    rescue AWS::S3::Errors::InvalidAccessKeyId
      STDERR.puts "Invalid AWS Access Key. Do you have correct credentials?"
      exit(1)
    rescue AWS::S3::Errors::SignatureDoesNotMatch
      STDERR.puts "Is your secret access key correct?"
      exit(1)
  end

  # Add the lifecycle rule to transition immediately to Glacier
  def lifecycle_setup(bucket)
    puts "Setting up lifecycle policy on '#{bucket.name}' bucket"
    bucket.lifecycle_configuration.clear
    bucket.lifecycle_configuration.update do
      add_rule '', {
        :glacier_transition_time => TRANSITION_TIME,
        :id                      => RULE_ID
        }
    end
  end

end
