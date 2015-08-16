require 'aws-sdk'
require 'progressbar'

class GlacierBackup::Bucket
  RULE_ID = 'glacier-backup'
  TRANSITION_TIME = 0

  def initialize(access_key, secret_key, bucket_name, region)
    Aws.config.update(
      :region      => region,
      :credentials => Aws::Credentials.new(access_key, secret_key)
    )
    @client = Aws::S3::Client.new(
      # Network transport reliability options
      :http_open_timeout => 60,
      :http_read_timeout => 300,
      :retry_limit       => 10
    )

    @bucket = Aws::S3::Resource.new(:client => @client).bucket(bucket_name)

    # Test for presence/ownership of the bucket
    if @bucket.exists?
      begin
        @bucket.acl
      rescue Aws::S3::Errors::AccessDenied
        STDERR.puts "Access Denied to S3 bucket '#{bucket_name}'. Do you own it?"
        exit(1)
      end
    else
      @client.create_bucket(
        :bucket                      => bucket_name,
        :create_bucket_configuration => {
          :location_constraint => region
        }
      )
      puts "Created S3 bucket '#{bucket_name}'"
    end

    # Ensure the bucket lifecycle is set up correctly
    lifecycle = @bucket.lifecycle
    lifecycle_setup() if lifecycle.rules.length == 1 and lifecycle.rules.first.id != RULE_ID
    lifecycle_setup() if lifecycle.rules.length != 1

    rescue Aws::S3::Errors::InvalidAccessKeyId
      STDERR.puts "Invalid AWS Access Key. Do you have correct credentials?"
      exit(1)
    rescue Aws::S3::Errors::SignatureDoesNotMatch
      STDERR.puts "Is your secret access key correct?"
      exit(1)
  end # initialize

  # Add the lifecycle rule to transition immediately to Glacier
  def lifecycle_setup()
    puts "Setting up lifecycle policy on '#{@bucket.name}' bucket"
    @bucket.lifecycle.delete
    @bucket.lifecycle.put(
      :lifecycle_configuration => {
        :rules => [
          :id         => RULE_ID,
          :prefix     => '/',
          :status     => 'Enabled',
          :transition => {
            :storage_class => 'GLACIER',
            :days          => TRANSITION_TIME
          }
        ]
      }
    )
  end # lifecycle_setup

  def archive(file, hash)
    # strip the leading slash so we can use the whole path inside the bucket
    shortfile = file.gsub(/^\//, '')

    # set up a progress bar for the upload
    content_length = File.stat(file).size
    pbar = ProgressBar.new(File.basename(file), content_length)

      GlacierBackup::retry do
        File.open(file,'r') do |f|
          @client.put_object(
            :body           => f,
            :bucket         => @bucket.name,
            :content_length => content_length,
            :key            => shortfile,
            :storage_class  => 'REDUCED_REDUNDANCY',
            :metadata       => {
              :hash => hash
            }
          )
          # TODO: Fix the progress bar again in some way. Maybe with multi-part
          # uploads?
          pbar.finish
        end
      end
  end # archive

end
