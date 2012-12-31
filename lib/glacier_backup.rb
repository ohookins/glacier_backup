module GlacierBackup
  RETRIES = 3

  extend self

  # Simple wrapper around AWS network transfers to make them slightly more
  # resilient to transient failures.
  def retry
    attempts = 0

    while true
      begin
        yield
      rescue AWS::Core::Client::NetworkError, AWS::S3::Errors::InternalError
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

end
