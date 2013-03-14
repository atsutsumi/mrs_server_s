# encoding: utf-8

require_relative 'base_handler'

module Mrsss

  class TarHandler

    #
    # 初期化処理
    #
    def initialize(mode, channel_id)
      @mode = mode
      @channel_id = channel_id
    end
    
    #
    # TARデータの処理
    #
    def handle(contents)
      
      # TARデータの解凍
      archive = Lgdisit::Util::Tar::Archive.new(contents,{})
      
      # ファイル数分ファイルをアップロード
      attributes = []
      archive.files.each do |file|
        attribute = {}
        token = BaseHandler::post_uploads(file.read)
        unless token.blank?
          attribute['filename'] = file.name
          attribute['token'] = token
          attributes.push(attribute)
        end
      end
      
      # 送信電文作成
      issue_json = create_issue_json(attributes)
      
      # Redmineへ送信
      BaseHandler::post_issues(issue_json)

    end
    
private

    #
    # issue登録用のJSONデータを作成する
    #
    def create_issue_json(attributes)
      
      # 設定取得
      config = Lgdisit::get_redmine_config['tar_config']
      
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
      
      Lgdisit.logger.debug("-------------------- 送信JSONデータ --------------------")
      Lgdisit.logger.debug(json)
      Lgdisit.logger.debug("--------------------------------------------------------")

      json.to_json
      
    end

  end # TarHandler

end # Mrsss