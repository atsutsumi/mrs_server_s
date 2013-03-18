# -*- coding:utf-8 -*-
require "yaml"
require "log4r"
require "log4r/yamlconfigurator"
require 'stringio'
require 'zlib'
require 'zipruby'
require 'resque'
require 'active_support/core_ext'

require_relative "mrsss/server"
require_relative "mrsss/message"
require_relative "mrsss/util"
require_relative "mrsss/handler"
require_relative "mrsss/parsers/parser"

module Mrsss

  # Gets lgdisit system logger.
  # ==== Return
  # log4r logger
  def self.logger
    @logger ||= Log4r::Logger["Log4r"] 
    return @logger
  end

  # Retrieves the jma server configuration hash values
  # ==== Return
  # configuration hash values
  def self.get_mrsss_config
    @mrsss_config ||= Util.get_yaml_config("mrsss_config.yml")
  end

  # Retrieves the Jma XML parse rule as hashvalues
  # ==== Return
  # parse rule hash values
  def self.get_jma_xml_parse_rule
    @jma_xml_parse_rule ||= YAML.load(File.open(File.join(Util.get_config_path(__FILE__), "jma_xml_parse_rule.yml")))
    return @jma_xml_parse_rule
  end

  # Retrieves the Ksn XML parse rule as hashvalues
  # ==== Return
  # parse rule hash values
  def self.get_ksn_xml_parse_rule
    @ksn_xml_parse_rule ||= YAML.load(File.open(File.join(Util.get_config_path(__FILE__), "ksn_xml_parse_rule.yml")))
    return @ksn_xml_parse_rule
  end

  def self.get_redmine_config
    @redmine_config ||= Util::get_yaml_config("redmine.yml")
    return @redmine_config
  end
  
  def self.get_jma_schema
    Dir.chdir(Util.get_schemas_path(__FILE__))
    @jma_schema ||= Nokogiri::XML::Schema(File.read("jmx.xsd"))
  end

  def self.get_river_schema
    Dir.chdir(Util.get_schemas_path(__FILE__))
    @jma_schema ||= Nokogiri::XML::Schema(File.read("river.xsd"))
  end

  # Sets up the configuration for log output.
  def self.load_log_config
    if Log4r::Logger["log4r"].nil?
      Log4r::YamlConfigurator.load_yaml_file(File.join(Util.get_config_path(__FILE__), "log4r.yml"))
    end
  end
  
  # Sets up configuration files and start jma server threads.
  def self.start_mrsss
		begin
      load_log_config
      config = get_mrsss_config

      threads = []
      # create threads from each entry of "threads" in the configuration yaml
      config['channels'].each do |channel_id, entry|
        thread = Thread.new do
					server = Server.new(channel_id, entry['port'], entry['archive_path'], config['mode'], config['need_checksum'])
          server.start
        end
        threads.push(thread)
        sleep 1
       end

    rescue => exception
      Mrsss.logger.fatal(exception)
		ensure
			if !threads.to_s.empty?
				threads.each do |t|
					t.join
				end
			end
    end
  end

end # Mrsss
