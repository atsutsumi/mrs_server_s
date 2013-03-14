# coding: UTF-8

require 'yaml'
require 'nokogiri'
require 'active_support/core_ext'
require_relative 'parse_util'

module Mrsss
  
  #
  # JMAのXMLデータを解析するクラス
  #
  class JmaXmlParser
    include ParseUtil
      
    # ---------------------------------------------------------------
    # public メソッド
    # ---------------------------------------------------------------
    #
    # 初期化処理
    #
    def initialize(doc)
      # 解析ルール
      @rule = Lgdisit.get_jma_xml_parse_rule
      # NokogiriでXML解析
      @xml = doc
      # 名前空間を無効にする!
      # 無効にしないとXPathで値を取得できない
      @xml.remove_namespaces!
    end
    
    #
    # xml_controlに設定する値を取得
    #
    def xml_control
      @xml.xpath(@rule['xml_control']).to_s
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
      if channel_id.nil?;raise NilError.new("channel_id is nil."); end 
      
      #Lgdisit.logger.debug("called tracier_id channel_id => #{channel_id}")
      
      # ルール設定ファイルには入力識別子単位で定義されている
      trackers_map = @rule['trackers'][channel_id]
      if trackers_map.nil?;raise NilError.new("tracksers_map is nil."); end 
      
      tracker_id = nil
      
      # トラッカーを決定するためのXPath取得
      location = trackers_map['path']
      unless location.blank?
        # XPathでタイトル取得
        title = @xml.xpath(location).to_s
        # typeHashからタイトルをキーにトラッカーIDを取得
        types = trackers_map['type']
        tracker_id = types[title]
      end
      
      # トラッカーIDが取得できない場合はデフォルトのトラッカーIDを取得
      if tracker_id.blank?
        tracker_id = trackers_map['default']
      end
      
      if tracker_id.nil?;raise NilError.new("tracker_id is nil."); end 
      tracker_id
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
        #Lgdisit.logger.debug("return default project_id")
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
    
    #
    # 地理系情報を取得
    #
    def issue_geographies
      
      # 戻り値用変数
      issue_geographies = []
      
      # 解析ルール取得
      geographies = @rule['issue_geographies']
      
      # 解析ルールのうちcoordinateを解析
      coordinate = geographies['coordinate']
      point_geographies = parse_issue_geography(coordinate, 'point')
      unless point_geographies.empty?
        #Lgdisit.logger.debug("point_geographies => #{point_geographies}")
        issue_geographies.concat(point_geographies)
      end
      
      # 解析ルールのうちlineを解析
      line = geographies['line']
      line_geographies = parse_issue_geography(line, 'line')
      unless line_geographies.empty?
        #Lgdisit.logger.debug("line_geographies => #{line_geographies}")
        issue_geographies.concat(line_geographies)
      end
      
      # 解析ルールのうちpolygonを解析
      polygon = geographies['polygon']
      polygon_geographies = parse_issue_geography(polygon, 'polygon')
      unless polygon_geographies.empty?
        #Lgdisit.logger.debug("polygon_geographies => #{polygon_geographies}")
        issue_geographies.concat(polygon_geographies)
      end
      
      # 解析ルールのうちlocationを解析
      location = geographies['location']
      location_geographies = parse_issue_geography(location, 'location')
      unless location_geographies.empty?
        #Lgdisit.logger.debug("location_geographies => #{location_geographies}")
        issue_geographies.concat(location_geographies)
      end
      issue_geographies
    end
    
    #
    # 地理系情報を解析
    # geokey -> 'coordinate'/'polygon'/'line'/'location'のいずれか
    #
    def parse_issue_geography(rules, geokey)
      
      issue_geographies = []
      
      rules.each do |item|
        
        # xpath
        location = item['path']
        # remarks
        remarks_path = item['remarks_path']
        # static_remarks
        static_remarks = item['static_remarks']
        # allow_type
        allow_type = item['allow_type']
        
        # xpathで取得できるNodeList全てに対して処理を行う
        @xml.xpath(location).each do |node|
          
          # 該当Nodeがtype属性を持ち、allow_typeの指定がある場合は一致するtypeを持つNodeの値のみ使用する
          type = node.xpath("../@type")[0].to_s
          unless type.blank?
            unless allow_type.blank?
              #Lgdisit.logger.debug("typeチェック => 許可タイプ:#{allow_type} 実際のタイプ:#{type}")
              # allow_typeの指定と異なるtype属性を持つNodeの場合は使用しない
              unless type == allow_type
                # typeとallow_typeが一致しない場合は該当データスキップ
                next
              end
            end
          end
          
          # 地理情報
          geo = node.to_s
          
          # 測地系情報
          datum = node.xpath("../@datum").to_s
          #Lgdisit.logger.debug("datum => #{datum}")
          
          # ---------------------------------------------------------
          # 備考文字列
          # parseRuleにREMARKS_PATHSが設定されている場合は配列に設定
          # されているXpathを使用して備考文字列を取得する
          # 設定されていない場合はSTATIC_REMARKSを使用して備考文字列を取得する
          # ---------------------------------------------------------
          remarks = ''
          if static_remarks.blank?
            unless remarks_path.blank?
              remarks = node.xpath(remarks_path).to_s
            end
          else
            remarks = static_remarks
          end
          
          # 備考の最後にtypeも設定する
          unless type.blank?
            remarks = "#{remarks} #{type}"
          end
          #Lgdisit.logger.debug("remarks => #{remarks}")
          
          # geokeyにより地理情報を変換してissue_geographyに格納
          issue_geography = {}
          if geokey == 'point'
            issue_geography_point = convert_point(geo)
            #Lgdisit.logger.debug("point => #{issue_geography_point}")
            issue_geography['point'] = issue_geography_point
          elsif geokey == 'line'
            issue_geography_line = convert_point_array(geo)
            #Lgdisit.logger.debug("line => #{issue_geography_line}")
            issue_geography['line'] = issue_geography_line
          elsif geokey == 'polygon'
            issue_geography_polygon = convert_point_array(geo)
            #Lgdisit.logger.debug("polygon => #{issue_geography_polygon}")
            issue_geography['polygon'] = issue_geography_polygon
          elsif geokey == 'location'
            #Lgdisit.logger.debug("location => #{geo}")
            issue_geography['location'] = geo
          end
          
          # 備考情報を格納
          unless remarks.blank?
            issue_geography['remarks'] = remarks
          end
          # 測地系情報を格納
          unless datum.blank?
            issue_geography['datum'] = datum
          end
          # 戻り値用配列に地理系情報Hashを追加
          issue_geographies.push(issue_geography)
        end
      end
      issue_geographies
    end
    
    #
    # プロジェクト自動送信フラグを取得
    #
    def is_autosend(disposition_no)
      autosend_nos = @rule['autosend_disposition_numbers']
      autosend_nos.include?(disposition_no)
    end
    
    #
    # プロジェクト自動立ち上げフラグを取得
    #
    def is_autolaunch
      # 震度による判定
      autolaunch_map = @rule['autolaunch']
      
      threshold = intensity_to_f(autolaunch_map['earthquake_threashold']) # しきい値
      location = autolaunch_map['earthquake_path']  # 震度取得用xpath
      
      nodelist = @xml.xpath(location)
      nodelist.each do |node|
        node_val = intensity_to_f(node.to_s)
        if node_val >= threshold
          return true
        end
      end
      
      # 津波の高さによる判定
      threshold = autolaunch_map['tsunami_threashold'] # しきい値
      location = autolaunch_map['tsunami_path']  # 震度取得用xpath
      
      nodelit = @xml.xpath(location)
      nodelist.each do |node|
        node_val = node.to_s.to_f
        if node_val >= threshold
          return true
        end
      end
      
      return false
    end
    
    #
    # 配備番号を取得
    #
    def disposition_number
      
      disposition_info = @rule['disposition']
      
      disposition_info.each do |info|
        
        disposition_number = info['number']
        disposition_paths = info['paths']
        disposition_paths.each do |aPath|
          node = @xml.xpath(aPath)
          unless node.empty?
            return disposition_number
          end
        end
      end
      nil
    end
    
    #
    # 自動送信時のメッセージを取得
    #
    def send_message
      ret_messages = {}
      send_message_info = @rule['send_message']
      send_message_info.each do |info|
        rest_parameter = info['parameter']
        max_length = info['max_length']
        paths = info['paths']
        message = ''
        paths.each do |path|
          txt = @xml.xpath(path).to_s
          unless txt.blank?
            if message.length == 0
              message = txt
            else
              message = message + ' ' + txt
            end
          end
        end
        unless message.blank?
          message = message.slice(0, max_length)
          ret_messages[rest_parameter] = message
        end
      end
      return ret_messages
    end
        
  end # JmaXmlParser
end # Mrsss
