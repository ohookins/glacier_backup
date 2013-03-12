require 'aws-sdk'
require 'progressbar'

class GlacierBackup::Bucket
  RULE_ID = 'glacier-backup'
  TRANSITION_TIME = 0

  def initialize(access_key, secret_key, bucket_name)
    s3 = AWS::S3.new(:access_key_id     => access_key,
                     :secret_access_key => secret_key,
                     # Network transport reliability options
                     :http_open_timeout => 60,
                     :http_read_timeout => 300,
                     :max_retries       => 10
                    )

    @bucket = s3.buckets[bucket_name]

    # Test for presence/ownership of the bucket
    if @bucket.exists?
      begin
        @bucket.acl
      rescue AWS::S3::Errors::AccessDenied
        STDERR.puts "Access Denied to S3 bucket '#{bucket_name}'. Do you own it?"
        exit(1)
      end
    else
      @bucket = s3.buckets.create(bucket_name)
      puts "Created S3 bucket '#{bucket_name}'"
    end

    # Ensure the bucket lifecycle is set up correctly
    lifecycle = @bucket.lifecycle_configuration
    lifecycle_setup() if lifecycle.rules.length == 1 and lifecycle.rules.first.id != RULE_ID
    lifecycle_setup() if lifecycle.rules.length != 1

    rescue AWS::S3::Errors::InvalidAccessKeyId
      STDERR.puts "Invalid AWS Access Key. Do you have correct credentials?"
      exit(1)
    rescue AWS::S3::Errors::SignatureDoesNotMatch
      STDERR.puts "Is your secret access key correct?"
      exit(1)
  end # initialize

  # Add the lifecycle rule to transition immediately to Glacier
  def lifecycle_setup()
    puts "Setting up lifecycle policy on '#{@bucket.name}' bucket"
    @bucket.lifecycle_configuration.clear
    @bucket.lifecycle_configuration.update do
      add_rule '', {
        :glacier_transition_time => TRANSITION_TIME,
        :id                      => RULE_ID
        }
    end
  end # lifecycle_setup

  def archive(file, hash)
    # strip the leading slash so we can use the whole path inside the bucket
    shortfile = file.gsub(/^\//, '')

    # set up a progress bar for the upload
    content_length = File.stat(file).size
    pbar = ProgressBar.new(File.basename(file), content_length)

      GlacierBackup::retry do
        obj = @bucket.objects[shortfile]
        File.open(file,'r') do |f|
          obj.write({
              :content_length     => content_length,
              :reduced_redundancy => true,
              :metadata           => {
                :hash               => hash
              }
          }) do |buffer, bytes|
            buffer.write(f.read(bytes))
            pbar.inc(bytes)
          end
          pbar.finish
        end
      end
  end # archive

end
