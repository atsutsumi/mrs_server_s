# coding: UTF-8

require 'yaml'
require 'nokogiri'
require 'active_support/core_ext'
require_relative 'parse_util'

module Mrsss
  
  #
  # 河川XMLを解析する
  #
  class KsnXmlParser 
  
    # ---------------------------------------------------------------
    # public メソッド
    # ---------------------------------------------------------------
    #
    # 初期化処理
    #
    def initialize(doc)
      # 解析ルール
      @rule = Lgdisit.get_ksn_xml_parse_rule
      # NokogiriでXML解析
      @xml = doc
      # 名前空間を無効にする!
      # 無効にしないとXPathで値を取得できない
      @xml.remove_namespaces!
    end
    
    #
    # xml_bodyに設定する値を取得
    #
    def xml_body
      @xml.xpath(@rule['xml_body']).to_s
    end

    #
    # xml_headに設定する値を取得
    #
    def xml_head
      @xml.xpath(@rule['xml_head']).to_s
    end

    #
    # トラッカーIDを取得
    #
    def tracker_id(channel_id)
      @rule['tracker']
    end

    #
    # プロジェクトIDを取得
    #
    def project_id
      projects_map = @rule['projects']
      location = projects_map['path']
      status = @xml.xpath(location).to_s
      types = projects_map['type']
      project_id = types[status]
      if project_id.blank?
        Lgdisit.logger.debug("return default project_id")
        project_id = types['default']
      end
      
      if project_id.nil?;raise NilError.new("project_id is nil."); end 
      project_id
    end

    #
    # issue_extrasに設定する値を取得
    #
    def issue_extras
      # 戻り値用ハッシュテーブル
      ret = {}
      issue_extras_map = @rule['issue_extras'] 
      # issue_extras に定義されいるxpath数分ループ
      issue_extras_map.each do |key, location|
        # xpathを使用して値を取得
        val = @xml.xpath(location).to_s
        # 戻りハッシュテーブルに値を設定
        ret[key] = val
      end
      ret
    end

  end # KsnXmlParser

end # Mrsss
