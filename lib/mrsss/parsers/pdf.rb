# encoding: utf-8

module Mrsss
  module Parsers
  
    class Pdf
  
      #
      # 初期化処理
      #
      def initialize(mode, channel_id)
        @mode = mode
        @channel_id = channel_id
        @log = Mrsss.parser_logger
      end
      
      #
      # PDFデータの処理
      #
      def handle(contents)
        
        # PDFデータのアップロード
        token = Redmine::post_uploads(contents)
        
        # トークンが取得できなかった場合は処理中断
        if token.blank?
          return
        end
        
        # 送信電文作成
        issue_json = create_issue_json(token)
        
        # Redmineへ送信
        Redmine::post_issues(issue_json)
        
      end
      
  private
  
      #
      # issue登録用のJSONデータを作成する
      #
      def create_issue_json(token)
        
        # 設定取得
        config = Mrsss::get_redmine_config['pdf_config']
        
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
        
        upload = {}
        upload['token'] = token
        upload['filename'] = config['filename']
        upload['description'] = config['description']
        upload['content_type'] = config['content_type']
        uploads = []
        uploads[0] = upload
        issue['uploads'] = uploads
        
        @log.debug("-------------------- 送信JSONデータ --------------------")
        @log.debug(json)
        @log.debug("--------------------------------------------------------")
  
        json.to_json
      end
  
    end #Pdf
  end # Parsers
end # Mrsss