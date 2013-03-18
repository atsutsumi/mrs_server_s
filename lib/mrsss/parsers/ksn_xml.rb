# encoding: utf-8

module Mrsss
  module Parsers
  
    #
    # 河川XMLデータを処理するクラス
    #
    class KsnXml
      
      #
      # 初期化処理
      #
      def initialize(mode, channel_id)
        @mode = mode
        @channel_id = channel_id
        @log = Mrsss.parser_logger
      end
      
      #
      # XMLデータの処理
      #
      def handle(contents)
        
        @xml = Nokogiri::XML(contents)
        
        # スキーマチェック
        schema = Mrsss::get_river_schema()
        is_valid = schema.valid?(@xml)
        if is_valid == false
          @log.error("XMLスキーマチェックエラーのため処理を中断します")
          return nil
        end
        
        @log.info("XMLスキーマチェック正常")
        
        # XML解析
        parse()
           
        # 送信電文作成
        issue_json = create_issue_json()
        
        # Redmineへ送信
        Redmine::post_issues(issue_json)
        
      end
      
private

      #
      # issue登録用のJSONデータを作成する
      #
      def create_issue_json()
        
        # issueに登録するためのJSONデータ用Hash
        json = {}
        issue = {}
        json['issue'] = issue
        
        # プロジェクトID
        issue['project_id'] = @project_id
        # トラッカーID
        issue['tracker_id'] = @tracker_id
        # XML_Head
        issue['xml_head'] = @xml_head
        # XML_Body
        issue['xml_body'] = @xml_body
        
        # issue_extras
        @issue_extras.each { |param, value|
          unless value.blank?
            issue[param] = value
          end
        }
        
        @log.debug("-------------------- 送信JSONデータ --------------------")
        @log.debug(json)
        @log.debug("--------------------------------------------------------")
  
        json.to_json
      end
  
      #
      # XMLの解析処理
      #
      def parse()
        
        # 名前空間を無効にする!
        # 無効にしないとXPathで値を取得できない
        @xml.remove_namespaces!
        
        # 解析ルールをロード
        @@rule ||= YAML.load(File.open(File.join(Util.get_config_path(__FILE__), "ksn_xml_parse_rule.yml")))
        
        # ---------------------------------------------------------------
        # XMLの解析作業開始
        # ---------------------------------------------------------------
        @xml_head = @xml.xpath(@@rule['xml_head']).to_s
        @xml_body = @xml.xpath(@@rule['xml_body']).to_s
        
        @tracker_id = @@rule['tracker']
        @project_id = project_id()
        
        @issue_extras = issue_extras()
        
      end
      
      #
      # プロジェクトIDを取得
      #
      def project_id
        projects_map = @@rule['projects']
        location = projects_map['path']
        status = @xml.xpath(location).to_s
        types = projects_map['type']
        project_id = types[status]
        if project_id.blank?
          @log.info("return default project_id")
          project_id = types['default']
        end
        project_id
      end
  
      #
      # issue_extrasに設定する値を取得
      #
      def issue_extras
        # 戻り値用ハッシュテーブル
        ret = {}
        issue_extras_map = @@rule['issue_extras'] 
        # issue_extras に定義されいるxpath数分ループ
        issue_extras_map.each do |key, location|
          # xpathを使用して値を取得
          val = @xml.xpath(location).to_s
          # 戻りハッシュテーブルに値を設定
          ret[key] = val
        end
        ret
      end

    end # KsnXml
  end # Parsers
end # Mrsss
