require 'digest'

module GlacierBackup
  RETRIES = 3
  DEFAULT_ALGORITHM = :sha1
  READ_SIZE = 2**16

  extend self

  # Simple wrapper around AWS network transfers to make them slightly more
  # resilient to transient failures.
  def retry
    attempts = 0

    while true
      begin
        yield
      rescue Aws::Core::Client::NetworkError, Aws::S3::Errors::InternalError
        attempts += 1
        break if attempts >= RETRIES
        STDERR.puts "Transfer failed, retrying (#{attempts} of #{RETRIES})"
        next
      else
        break
      end
    end

    if attempts >= RETRIES
      STDERR.puts "Transfer permanently failed. Giving up."
    end
  end

  # Flexible wrapper around the various hashing algorithms.
  def filehash(filename, algorithm = DEFAULT_ALGORITHM)
    algo_class = Digest.const_get(algorithm.to_s.upcase)

    # Safety check
    unless algo_class.class == Class and algo_class.respond_to?(:new)
      raise "Unknown filehash provider #{algo_class}"
    end

    hash = algo_class.new()
    File.open(filename,'r') do |f|
      until f.eof?
        hash.update(f.read(READ_SIZE))
      end
    end

    return hash.hexdigest
  end
end
