require 'erb'
require 'yaml'

module Ridgepole
  class Config
    class << self
      def load(config, env = 'development')
        config = ENV.fetch(Regexp.last_match(1)) if config =~ /\Aenv:(.+)\z/

        parsed_config = if File.exist?(config)
                          parse_config_file(config)
                        elsif (expanded = File.expand_path(config)) && File.exist?(expanded)
                          parse_config_file(expanded)
                        elsif Gem::Version.new(Psych::VERSION) >= Gem::Version.new('3.1.0.pre1') # Ruby 2.6
                          YAML.safe_load(
                            ERB.new(config).result,
                            whitelist_classes: [],
                            whitelist_symbols: [],
                            aliases: true
                          )
                        else
                          YAML.safe_load(ERB.new(config).result, [], [], true)
                        end

        unless parsed_config.is_a?(Hash)
          parsed_config = parse_database_url(config)
        end

        if parsed_config.key?(env.to_s)
          parsed_config.fetch(env.to_s)
        else
          parsed_config
        end
      end

      private

      def parse_config_file(path)
        yaml = ERB.new(File.read(path)).result

        if Gem::Version.new(Psych::VERSION) >= Gem::Version.new('3.1.0.pre1') # Ruby 2.6
          YAML.safe_load(
            yaml,
            whitelist_classes: [],
            whitelist_symbols: [],
            aliases: true
          )
        else
          YAML.safe_load(yaml, [], [], true)
        end
      end

      def parse_database_url(config)
        uri = URI.parse(config)

        if [uri.scheme, uri.user, uri.host, uri.path].any? { |i| i.nil? || i.empty? }
          raise "Invalid config: #{config.inspect}"
        end

        {
          'adapter'  => uri.scheme,
          'username' => uri.user,
          'password' => uri.password,
          'host'     => uri.host,
          'port'     => uri.port,
          'database' => uri.path.sub(%r{\A/}, '')
        }
      end
    end
  end
end
