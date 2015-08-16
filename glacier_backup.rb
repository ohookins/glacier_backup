#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'find'

# Pull in libraries of glacier backup
$:.unshift(File.expand_path('../lib', __FILE__))
require 'glacier_backup'
require 'glacier_backup/config'
require 'glacier_backup/archive'
require 'glacier_backup/bucket'
require 'glacier_backup/signals'

# Read in configuration and initialise bucket settings
config = GlacierBackup::Config.config()
bucket = GlacierBackup::Bucket.new(
                                   config.aws[:key],
                                   config.aws[:secret],
                                   config.aws[:bucket],
                                   config.aws[:region]
                                  )

# Organise directories to be backed up by updatable backups (e.g directories
# containing TimeMachine fragments) and immutable backups (everything else).
directories = {}
config.directories.nil? || config.directories.each do |dir|
  puts "Processing #{dir} as regular backup directory."
  directories[dir] = :persist
end
config.timemachine.nil? || config.timemachine.each do |dir|
  puts "Processing #{dir} as TimeMachine backup directory."
  directories[dir] = :update
end

directories.each_pair do |directory,policy|
  directory = directory + '/' unless directory.end_with? '/'

  Find.find(directory).each do |file|
    hash = nil
    next unless File.file?(file) and File.readable?(file) and ! File.symlink?(file)

    # Chop off the leading slash so we can store the whole path nicely in S3
    shortfile = file.gsub(/^\//, '')
    result = Archive.where(:filename => shortfile)

    # Check for and create the ActiveRecord entry if missing
    if result.empty?
      archive = Archive.new(:filename    => shortfile,
                            :file_digest => hash ||= GlacierBackup::filehash(file)
                           )
      archive.save!
      puts "Created entry for #{shortfile} with hash #{hash}"
    else
      archive = result.first
    end

    # Verify the hash to see if the file has changed
    if config.verify or policy == :update
      hash ||= GlacierBackup::filehash(file)

      if archive.file_digest != hash
        puts "#{archive.filename} changed, #{archive.file_digest} => #{hash}"
      end
    end

    # Upload to S3 if not already there, or if the archive is updatable and the
    # hash has changed.
    if archive.archived_at == nil or (policy == :update and archive.file_digest != hash)
      bucket.archive(file, hash)

      # Update archive metadata
      archive.file_digest = hash
      archive.archived_at = Time.now
      archive.save!
      puts "#{shortfile} archived at #{archive.archived_at}"

      # Exit if we caught a SIGINT in the meantime
      exit(1) if $exit > 0
    end

  end # Find.find
end # config.directories.each
