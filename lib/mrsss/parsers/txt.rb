# encoding: utf-8

module Mrsss
  module Parsers
  
    class Txt
  
      #
      # 初期化処理
      #
      def initialize(mode, channel_id)
        @mode = mode
        @channel_id = channel_id
        @log = Mrsss.parser_logger
      end
      
      #
      # TXTデータの処理
      #
      def handle(contents)
        
        attributes = []
        
        # contentsがファイルの配列のため
        # 全てのファイルに対してuploadを行う
        contents.each do |entry|
          attribute = {}
          file = entry['file']
          name = entry['name']
          token = Redmine.post_uploads(file)
          unless token.blank?
            attribute['filename'] = name
            attribute['token'] = token
            attributes.push(attribute)
          end
        end
        
        if attributes.empty?
          @log.warning("Redmineへのファイルアップロードに成功しなかったため処理を中断します")
          return nil
        end
        
        # 送信電文作成
        issue_json = create_issue_json(attributes)
        
        # Redmineへ送信
        Redmine::post_issues(issue_json)
  
      end
      
private
  
      #
      # issue登録用のJSONデータを作成する
      #
      def create_issue_json(attributes)
        
        # 設定取得
        config = Mrsss::get_redmine_config['txt_config']
        
        # issueに登録するためのJSONデータ用Hash
        json = {}
        issue = {}
        json['issue'] = issue
        
        # プロジェクトID
        issue['project_id'] = config['project_id']
        # トラッカーID
        issue['tracker_id'] = config['tracker_id']
        # 題名
        issue['subject'] = config['subject']
        
        uploads = []
        issue['uploads'] = uploads
        attributes.each do |attribute|
          upload = {}
          upload['token'] = attribute['token']
          upload['filename'] = attribute['filename']
          upload['description'] = config['description']
          upload['content_type'] = config['content_type']
          uploads.push(upload)
        end
        
        @log.debug("-------------------- 送信JSONデータ --------------------")
        @log.debug(json)
        @log.debug("--------------------------------------------------------")
  
        json.to_json
        
      end  
  
    end #Txt
  end # Parsers
end # Mrsss