require 'active_record'

# Establish the "connection" to the database. Hard-coded for now.
ActiveRecord::Base.establish_connection(
  :adapter    => "sqlite3",
  :database   => File.join(ENV['HOME'], '.glacierbackup.sqlite')
)
MIGRATIONS_PATH = File.expand_path('../../../migrations', __FILE__)
ActiveRecord::Migrator.migrations_path = MIGRATIONS_PATH

# Ensure the database is up to date with the latest schema.
available_migrations = ActiveRecord::Migrator.migrations(MIGRATIONS_PATH)
if ActiveRecord::Migrator.current_version < available_migrations.last.version
  puts "Creating and/or updating database schema..."
  ActiveRecord::Migrator.up(MIGRATIONS_PATH)
end

class Archive < ActiveRecord::Base; end
