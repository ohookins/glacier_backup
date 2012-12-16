require 'active_record'

# Establish the "connection" to the database. Hard-coded for now.
ActiveRecord::Base.establish_connection(
  :adapter    => "sqlite3",
  :database   => File.join(ENV['HOME'], '.glacierbackup.sqlite')
)

# Perform the initial table creation here if it doesn't exist.
if ActiveRecord::Migrator.current_version == 0
  puts "Creating initial database layout..."
  ActiveRecord::Migrator.up(File.expand_path('../../../migrations', __FILE__))
end

class Archive < ActiveRecord::Base; end

