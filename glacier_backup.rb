#!/usr/bin/env ruby

require 'rubygems'
require 'digest'
require 'find'
require 'json'

# Pull in libraries of glacier backup
$:.unshift(File.expand_path('./lib'))
require 'glacier_backup'
require 'glacier_backup/config'
require 'glacier_backup/archive'
require 'glacier_backup/bucket'

# Read in configuration and initialise bucket settings
config = GlacierBackup::Config.config()
bucket = GlacierBackup::Bucket.create(config.aws[:key],
                                      config.aws[:secret],
                                      config.aws[:bucket]
                                     )

config.directories.each do |directory|
  Find.find(directory)
end
exit(0)

foo do
  Find.find(path) do |file|
    # Only want to consider actual files
    next unless File.file?(file)

    # Error out on unreadable files but continue on
    if ! File.readable?(file)
      STDERR.puts "\n  #{file} unreadable"
      next
    end

    # Stream the file rather than read it all into memory.
    digest = Digest::SHA2.new()
    File.open(file, 'r') do |f|
      while ! (buffer = f.read(2**16)).nil?
        digest.update(buffer)
      end
    end
    hex = digest.hexdigest()

    # Skip empty files
    next if hex == 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'

    # Keep track of duplicates
    if hashes.has_key?(hex)
      hashes[hex].push(file)
      puts "\n  #{hex} duplicate: #{file}"
    else
      hashes[hex] = [file]
    end

    total_files += 1
    print "\r#{total_files} files read"
  end

  outfile = File.join(out_prefix, path.gsub('/','_') + '.json')
  File.open(outfile,'w') do |f|
    f.write(JSON::dump(hashes))
  end
  total_hashes += hashes.length
  puts "\nCalculated and wrote #{hashes.length} hashes for #{total_files} files."
end
