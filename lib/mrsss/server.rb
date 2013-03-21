# coding: UTF-8

module Mrsss

  #
  # JMAソケット手順に従ってデータを受信するサーバクラスです。1ポートに対して当クラスのインスタンスを1つ割り当ててください。
  #
  class Server
    
    # クライアントから受信するデータの最大サイズ
    MAX_BUFFER = 720010
    
    #
    # 初期化処理です。
    #
    # ==== Args
    # _channel_id_ :: データの入力元を表す識別子
    # _port_ :: ポート番号
    # _archive_path_ :: アーカイブ先ディレクトリ
    # _mode_ :: 動作モード(0:通常 1:訓練 2:試験)
    # _need_checksum_ :: チェックサムの実施有無(true:チェックサム実施 false:チェックサム実施なし)
    # ==== Return
    # ==== Raise
    def initialize(channel_id, port, archive_path, mode, need_checksum)
      
      raise ArgumentError.new("パラメータエラー。設定ファイルを確認してください。") if channel_id.blank? || port.blank? || archive_path.blank?
      
      @channel_id = channel_id
      @port = port
      @archive_path = archive_path
      @mode = mode
      @need_checksum = need_checksum
      @saved_message = nil
      @log = Mrsss.server_logger
    end
    
    #
    # サーバの受信待ち処理を開始します。サーバソケットを許可モードでオープンしクライアントからの接続を待ちます。
    #
    # ==== Args
    # ==== Return
    # ==== Raise
    def start
      
      begin
        str_log = "[#{@channel_id}] JMA受信サーバ起動\n"
        str_log = "#{str_log}--------------------------------------------------------------------------------\n"
        str_log = "#{str_log}* チャネル識別子       [#{@channel_id}]\n"
        str_log = "#{str_log}* 受信ポート           [#{@port}]\n"
        str_log = "#{str_log}* アーカイブパス       [#{@archive_path}]\n"
        str_log = "#{str_log}* 通常/訓練/試験モード [#{@mode}]\n"
        str_log = "#{str_log}* チェックサム実施有無 [#{@need_checksum}]\n"
        str_log = "#{str_log}--------------------------------------------------------------------------------"
        @log.info(str_log)
        
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
        
      rescue => error
				@log.fatal("[#{@channel_id}] ソケット接続待ちで例外が発生しました。");
				@log.fatal(error)
      ensure
			  # サーバクローズ
			  unless @server.nil?
          @server.close
			  end
			end
			
      @log.info("[#{@channel_id}] JMA受信サーバを停止します")
      @saved_message = nil
    end
    
    #
    # 接続が確立したソケットに対してデータ受信処理を行います。
    #
    # ==== Args
    # _session_ :: クライアントと接続が確立したTCPSocketインスタンス
    # ==== Return
    # ==== Raise
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
      rescue => error
        @log.fatal("[#{@channel_id}] データ受信待ちで例外が発生しました。");
        @log.fatal(error)
      ensure
        unless session.nil?
          session.close
        end
      end
      
      @log.info("[#{@channel_id}] データ受信待ちを停止します")
      @saved_message = nil
    end
    
    #
    # 受信したデータを解析します。
    #
    # ==== Args
    # _data_ :: ソケットから受信したデータ
    # _session_ :: クライアントと接続が確立したTCPSocketインスタンス
    # ==== Return
    # ==== Raise
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
        @log.debug("[#{@channel_id}] データが揃ったため後続処理を行います")
        @saved_message = nil
      else
      # データ分割の場合
        @log.debug("[#{@channel_id}] 分割受信のため再度データ受信待ち状態になります")
        @saved_message = message
        return  nil # 分割データの場合は処理終了
      end
      
      str_log = "[#{@channel_id}] JMA受信データ\n"
      str_log = "#{str_log}--------------------------------------------------------------------------------\n"
      str_log = "#{str_log}* メッセージ長    [#{message.userdata_length}]\n"
      str_log = "#{str_log}* メッセージ種別  [#{message.message_type}]\n"
      str_log = "#{str_log}--------------------------------------------------------------------------------"
      @log.info(str_log)
  
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
    end
    
  end # Server
end # Mrsss