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
        @log = Mrsss.logger
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
        
        @log.info("XMLスキーマチェック正常")
        
        # XML解析
        parser()
           
        # 送信電文作成
        issue_json = create_issue_json()
        
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

    end # KsnXml
  end # Parsers
end # Mrsss