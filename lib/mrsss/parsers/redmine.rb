# encoding: utf-8

module Mrsss
  module Parsers
    module Redmine
      
      #
      # issues発行
      #
      def self.post_issues(data)
        # ロガー取得
        log = Mrsss.logger
        
        # Redmineへissuesを発行するための各種設定
        config = Mrsss::get_redmine_config()['issues']
        
        # urlの作成
        url = create_url(config)
        
        log.info("-------------------- Rest送信データ --------------------")
        log.info("    url : #{url}")
        log.info("    timeout : #{config['timeout']}")
        log.info("    open_timeout : #{config['open_timeout']}")
        log.info("--------------------------------------------------------")
        
        # post送信
        begin
          response = RestClient.post url, data, :content_type => :json, :timeout => config['timeout'], :open_timeout => config['open_timeout']
        rescue => exception
          log.error("Rest送信でエラーが返却されました")
          log.error(exception)
          log.error(response)
          return nil
        end
        
        if response.code == 200 || response.code == 201
          log.info("---------------- Rest送信が成功しました ----------------")
        else
          log.info("---------------- Rest送信に失敗しました ----------------")
          log.info(response)
        end
      end
      
      #
      # upload発行
      # tokenを返却
      #
      def self.post_uploads(data)
        # ロガー取得
        log = Mrsss.logger
        
        p data
        
        # Redmineへuploadsを発行するための各種設定
        config = Mrsss::get_redmine_config()['uploads']
        
        # urlの作成
        url = create_url(config)
        
        log.info("-------------------- Rest送信データ --------------------")
        log.info("    url : #{url}")
        log.info("    timeout : #{config['timeout']}")
        log.info("    open_timeout : #{config['open_timeout']}")
        log.info("--------------------------------------------------------")
        
        begin
          response = RestClient.post url, data, :content_type => "application/octet-stream", :timeout => config['timeout'], :open_timeout => config['open_timeout']
        rescue => exception
          log.error("Rest送信でエラーが返却されました")
          log.error(exception)
          log.error(response)
          return nil
        end
        
        # responseからトークンを取得
        if response.code == 201
          json_response = JSON.parse(response)
          return json_response['upload']['token']
        else
          log.warn("tokenが返却されませんでした")
          log.warn(response)
          return nil
        end
      end
      
      #
      # URLを作成する
      #
      def self.create_url(config)
        # urlの作成
        basic_user = config['basic_user']
        basic_password = config['basic_password']
        url = ''
        if basic_user.blank? || basic_password.blank?
          url = "#{config['protocol']}://#{config['site']}/#{config['prefix']}&key=#{config['api_key']}"
        else
          url = "#{config['protocol']}://#{basic_user}:#{basic_password}@#{config['site']}/#{config['prefix']}&key=#{config['api_key']}"
        end
        url
      end
      
    end # Redmine
  end # Parsers
end # Mrsss
