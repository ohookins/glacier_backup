#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'progressbar'
require 'find'

# Pull in libraries of glacier backup
$:.unshift(File.expand_path('./lib'))
require 'glacier_backup'
require 'glacier_backup/config'
require 'glacier_backup/archive'
require 'glacier_backup/bucket'
require 'glacier_backup/signals'

# Read in configuration and initialise bucket settings
config = GlacierBackup::Config.config()
bucket = GlacierBackup::Bucket.create(config.aws[:key],
                                      config.aws[:secret],
                                      config.aws[:bucket]
                                     )

config.directories.each do |directory|
  Find.find(directory).each do |file|
    hash = nil
    next unless File.file?(file) and File.readable?(file) and ! File.symlink?(file)

    # Chop off the leading slash so we can store the whole path nicely in S3
    shortfile = file.gsub(/^\//, '')
    result = Archive.where(:filename => shortfile)

    # Check for and create the ActiveRecord entry if missing
    if result.empty?
      archive = Archive.new(:filename => shortfile,
                            :md5      => hash ||= GlacierBackup::filehash(file)
                           )
      archive.save!
      puts "Created entry for #{shortfile} with hash #{hash}"
    else
      archive = result.first
    end

    # Verify the hash to see if the file has changed
    if config.verify
      hash ||= GlacierBackup::filehash(file)

      if archive.md5 != hash
        puts "#{archive.filename} changed, #{archive.md5} => #{hash}"
      end
    end

    # Upload to S3 if not already there
    if archive.archived_at == nil
      content_length = File.stat(file).size
      pbar = ProgressBar.new(shortfile, content_length)

      GlacierBackup::retry do
        obj = bucket.objects[shortfile]
        File.open(file,'r') do |f|
          obj.write(:content_length => content_length,
                   :reduced_redundancy => true
                   ) do |buffer, bytes|
            buffer.write(f.read(bytes))
            pbar.inc(bytes)
          end
          pbar.finish
        end
      end

      # Update archive time
      archive.archived_at = Time.now
      archive.save!
      puts "#{shortfile} archived at #{archive.archived_at}"

      # Exit if we caught a SIGINT in the meantime
      exit(1) if $exit > 0
    end

  end # Find.find
end # config.directories.each
