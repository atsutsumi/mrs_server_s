# coding: UTF-8

module Mrsss

  #
  # JMAソケット手順に従ってデータを受信するサーバクラス
  # クライアント1つ(1ポート)に対して当クラスのインスタンスを1つ割り当ててください
  #
  class Server
    
    # -----------------------------------------------------
    # 変数定義
    # -----------------------------------------------------
    # 定数
    MAX_BUFFER = 720010 # クライアントから受信するデータの最大サイズ
    
    
    # -----------------------------------------------------
    # public メソッド
    # -----------------------------------------------------
    #
    # インスタンス初期化処理
    # 引数で指定されたパラメータをインスタンス変数として保持
    # ==== Args
    # ==== Return
    # ==== Raise
    def initialize(channel_id, port, archive_path, mode, need_checksum)
      @channel_id = channel_id
      @port = port
      @archive_path = archive_path
      @mode = mode
      @need_checksum = need_checksum
      @saved_message = nil
      @log = Mrsss.server_logger
    end
    
    #
    # 受信待ち開始
    # ==== Args
    # ==== Return
    # ==== Raise
    def start
      
      begin
      
        @log.info("--------------------------------------------------------------------------------")
        @log.info("    JMA受信サーバ起動")
        @log.info("    チャネル識別子       [#{@channel_id}]")
        @log.info("    受信ポート           [#{@port}]")
        @log.info("    アーカイブパス       [#{@archive_path}]")
        @log.info("    通常/訓練/試験モード [#{@mode}]")
        @log.info("    チェックサム         [#{@need_checksum}]")
        @log.info("--------------------------------------------------------------------------------")
        
        # TCPServerインスタンス生成
        @server = @server || TCPServer.open(@port)
        
      	# Runs event loop.
        while true
    			# to avoid heavy load on CPU
          sleep(0.1)
          @log.info("[#{@channel_id}] 接続待ち...")
          
          # クライアントからの接続待ち
          # このタイミングでスレッドブロックとなる
          session = @server.accept
          
          @log.info("[#{@channel_id}] 接続しました")
          
          # 新規にスレッド実行
          Thread.new(session) { |c|
            handle_request(c)
          }
          
        end
        
      rescue => exception
				@log.fatal(exception)
      ensure
			  # サーバクローズ
			  unless @server.nil?
          @server.close
			  end
			end
      @log.info("[#{@channel_id}] JMA受信サーバを停止します")
      @saved_message = nil
    end # start
    
    
    # -----------------------------------------------------
    # privateメソッド定義
    # -----------------------------------------------------
private
    
    #
    # クライアントからのデータを受信
    #
    def handle_request(session)
      
      begin
      	# Runs event loop.
        while true
          
    			# to avoid heavy load on CPU
          sleep(0.1)
          
          @log.info("[#{@channel_id}] データ受信待ち...")
          
          data = session.recv(MAX_BUFFER)
          
          @log.info("[#{@channel_id}] データを受信しました データ長[#{data.length}]")
          
          # 入力がなくなれば処理終了
          break if data.empty?
          
          # データ解析処理
          handle_data(data, session)
        
        end
      rescue => exception
        @log.fatal(exception)
      ensure
        unless session.nil?
          session.close
        end
      end
      @log.info("[#{@channel_id}] データ受信待ちを停止します")
      @saved_message = nil
      nil
    end # handle_requst
    
    #
    # クライアントからのデータを解析
    #
    def handle_data(data, session)
      
      # 分割データではない場合は受信したデータで新規にMessageインスタンスを作成
      # 分割データの場合は保存されているMessageインスタンスにデータを結合
      if @saved_message.blank?
        @log.debug("[#{@channel_id}] 新規の受信データです")
        message = Message.new(data)
      else
        @log.debug("[#{@channel_id}] 分割の受信データです")
        message = @saved_message.append(data)
      end
      
      # 分割データを判定
      if message.complete?
      # データ分割ではない場合
        @log.debug("[#{@channel_id}] データが揃ったため継続処理を行います")
        @saved_message = nil
      else
      # データ分割の場合
        @log.debug("[#{@channel_id}] 分割受信のため再度データ受信待ち状態になります")
        @saved_message = message
        return  nil # 分割データの場合は処理終了
      end
      
      @log.info("-----------------------------------------------------------")
      @log.info("    JMAソケットデータ")
      @log.info("    メッセージ長    [#{message.userdata_length}]")
      @log.info("    メッセージ種別  [#{message.message_type}]")
      @log.info("-----------------------------------------------------------")
  
      # ヘルスチェック要求の場合はヘルスチェック応答を返却
      if message.healthcheck?
        @log.info("[#{@channel_id}] ヘルスチェックのため応答")
        session.write(Message.HELTHCHK_RESPONSE)
        session.flush
      # チェックポイント要求の場合はチェックポイント応答を返却
      elsif message.checkpoint?
        @log.info("[#{@channel_id}] チェックポイントのため応答")
        session.write(message.checkpoint_response)
        session.flush
      else
        @log.info("[#{@channel_id}] ユーザデータのため解析")
        handler = Handler.new(@channel_id, @archive_path, @mode, @need_checksum)
        handler.handle(message)
      end
      @saved_message = nil
      nil
    end
    
  end # Server

end # Mrsss