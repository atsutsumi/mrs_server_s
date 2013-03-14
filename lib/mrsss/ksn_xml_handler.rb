# encoding: utf-8

require 'nokogiri'
require_relative 'base_handler'
require_relative 'ksn_xml_parser'

module Mrsss
  
  #
  # 河川XMLデータを処理するクラス
  #
  class KsnXmlHandler
    
    #
    # 初期化処理
    #
    def initialize(mode, channel_id)
      @mode = mode
      @channel_id = channel_id
    end
    
    #
    # XMLデータの処理
    #
    def handle(contents)
      
      # スキーマチェック
      xml = Nokogiri::XML(contents)
      @@schema ||= Nokogiri::XML::Schema(File.read('/Users/igakuratakayuki/RubyWorkspace/lgdisit/bin/river.xsd')) 
      valid_schema = @@schema.valid?(xml)
      if valid_schema == false
        Lgdisit.logger.error("XMLスキーマチェックエラーのため処理を中断します")
        return nil
      end
      
      Lgdisit.logger.info("XMLスキーマチェック正常")
            
      # 送信電文作成
      issue_json = create_issue_json(xml)
      
      # Redmineへ送信
      BaseHandler::post_issues(issue_json)
      
    end
    
private

    #
    # issue登録用のJSONデータを作成する
    #
    def create_issue_json(xml)
      
      # XML解析
      parser = KsnXmlParser.new(xml)
      
      # issueに登録するためのJSONデータ用Hash
      json = {}
      issue = {}
      json['issue'] = issue
      
      # プロジェクトID
      issue['project_id'] = parser.project_id
      # トラッカーID
      issue['tracker_id'] = parser.tracker_id(@channel_id)
      # XML_Head
      issue['xml_head'] = parser.xml_head
      # XML_Body
      issue['xml_body'] = parser.xml_body
      
      # issue_extras
      issue_extras = parser.issue_extras
      issue_extras.each { |param, value|
        unless value.blank?
          issue[param] = value
        end
      }
      
      Lgdisit.logger.debug("-------------------- 送信JSONデータ --------------------")
      Lgdisit.logger.debug(json)
      Lgdisit.logger.debug("--------------------------------------------------------")

      json.to_json
    end

  end # KsnXmlHandler

end # Mrsss
