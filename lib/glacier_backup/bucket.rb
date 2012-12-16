require 'aws-sdk'

module GlacierBackup::Bucket
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

    if lifecycle.rules.length > 0
      # XXXX: Debugging only for now.
      puts lifecycle.rules.length
      lifecycle.rules.each { |r| puts r.inspect }
    else
      # This is necessary as the SDK does not yet support transition policies
      bucket.lifecycle_configuration = <<-XML
        <LifecycleConfiguration>
          <Rule>
            <ID>glacier-backup-immediately</ID>
            <Prefix></Prefix>
            <Status>Enabled</Status>
            <Transition>
              <Days>0</Days>
              <StorageClass>GLACIER</StorageClass>
            </Transition>
          </Rule>
        </LifecycleConfiguration>
      XML
    end

    rescue AWS::S3::Errors::InvalidAccessKeyId
      STDERR.puts "Invalid AWS Access Key. Do you have correct credentials?"
      exit(1)
    rescue AWS::S3::Errors::SignatureDoesNotMatch
      STDERR.puts "Is your secret access key correct?"
      exit(1)
  end
end
