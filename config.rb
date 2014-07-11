module DnsZones
  class Config
    class << self
      attr_reader :config
    
      def init
        @config = YAML.load(File.read(File.join(File.dirname(__FILE__), "config.yml")))
      end
      
      def get(key)
        init if @config.nil?
        @config[key]
      end
    end
  end
end