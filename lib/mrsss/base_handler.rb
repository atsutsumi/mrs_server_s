# encoding: utf-8

require 'json'
require 'rest_client'

module Mrsss

  module BaseHandler
    
    #
    # issues発行
    #
    def self.post_issues(data)
      # Redmineへissuesを発行するための各種設定
      config = Lgdisit::get_redmine_config()['issues']
      
      # urlの作成
      url = create_url(config)
      
      #Lgdisit.logger.info("-------------------- Rest送信データ --------------------")
      #Lgdisit.logger.info("url : #{url}")
      #Lgdisit.logger.info("timeout : #{config['timeout']}")
      #Lgdisit.logger.info("open_timeout : #{config['open_timeout']}")
      #Lgdisit.logger.info("--------------------------------------------------------")
      p "-------------------- Rest送信データ --------------------"
      p "url : #{url}"
      p "timeout : #{config['timeout']}"
      p "open_timeout : #{config['open_timeout']}"
      p "--------------------------------------------------------"
      
      # post送信
      begin
        RestClient.post url, data, :content_type => :json, :timeout => config['timeout'], :open_timeout => config['open_timeout']
      rescue => e
        p "Rest送信でエラーが返却されました"
        p e
        p e.response
      end
      
    end
    
    #
    # upload発行
    # tokenを返却
    #
    def self.post_uploads(data)
      # Redmineへuploadsを発行するための各種設定
      config = Lgdisit::get_redmine_config()['uploads']
      
      # urlの作成
      url = create_url(config)
      
      Lgdisit.logger.info("-------------------- Rest送信データ --------------------")
      Lgdisit.logger.info("url : #{url}")
      Lgdisit.logger.info("timeout : #{config['timeout']}")
      Lgdisit.logger.info("open_timeout : #{config['open_timeout']}")
      Lgdisit.logger.info("--------------------------------------------------------")
      
      begin
        response = RestClient.post url, data, :content_type => "application/octet-stream", :timeout => config['timeout'], :open_timeout => config['open_timeout']
      rescue => e
        Lgdisit.logger.warn("Rest送信でエラーが返却されました")
        Lgdisit.logger.warn(e)
        return nil
      end
      
      # responseからトークンを取得
      if response.code == 201
        json_response = JSON.parse(response)
        return json_response['upload']['token']
      end

      Lgdisit.logger.warn("tokenが返却されませんでした")
      Lgdisit.logger.warn(response)

      return nil
    end
    
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
    
  end # BaseHandler

end # Mrsss
