require 'ostruct'
require 'yaml'

module GlacierBackup::Config
  extend self

  def config
    config_path = File.expand_path(File.join(ENV['HOME'],'.glacierbackup.yml'))

    raise "#{config_path} configuration file not found" unless File.exist?(config_path)

    config_hash = YAML::load_file(config_path)
    return OpenStruct.new(config_hash)
  end
end
