# encoding: utf-8

require 'nokogiri'
require_relative 'base_handler'
require_relative 'jma_xml_parser'

module Mrsss
  
  #
  # JMAのXMLを処理するクラス
  #
  class JmaXmlHandler
  
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
      #@@schema ||= Nokogiri::XML::Schema(File.read('/Users/igakuratakayuki/RubyWorkspace/lgdisit/bin/jmx.xsd')) 
      #valid_schema = @@schema.valid?(xml)
      #if valid_schema == false
      #  Lgdisit.logger.error("XMLスキーマチェックエラーのため処理を中断します")
      #  return nil
      #end
      
      #Lgdisit.logger.info("XMLスキーマチェック正常")
            
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
      parser = JmaXmlParser.new(xml)
      
      # issueに登録するためのJSONデータ用Hash
      json = {}
      issue = {}
      json['issue'] = issue
      
      # プロジェクトID
      issue['project_id'] = parser.project_id
      # トラッカーID
      issue['tracker_id'] = parser.tracker_id(@channel_id)
      # XML_Control
      issue['xml_control'] = parser.xml_control
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
      
      # issue_geographies
      issue['issue_geographies'] = parser.issue_geographies
      
      # send_target
      disposition_number = parser.disposition_number
      # 配備番号がある場合はメッセージと自動送信フラグを取得
      unless disposition_number.blank?
        issue['send_target'] = disposition_number
        
        # 自動送信の判定
        if parser.is_autosend(disposition_number)
          issue['auto_send'] = '1'
        end
        
        # メッセージ
        message_info = parser.send_message
        unless message_info.empty?
          message_info.each { |key, value|
            unless value.blank?
              issue[key] = value
            end
          }
        end
      end
      
      # 自動プロジェクト立ち上げの判定
      if parser.is_autolaunch
        issue['auto_launch'] = '1'
      end
      
      #Lgdisit.logger.debug("-------------------- 送信JSONデータ --------------------")
      #Lgdisit.logger.debug(json)
      #Lgdisit.logger.debug("--------------------------------------------------------")

      json.to_json
    end
    
  end # JmaXmlHandler

end # Mrsss
