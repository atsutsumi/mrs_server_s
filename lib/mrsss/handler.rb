# coding: UTF-8

module Mrsss

  # 
  # 外部入力先より受信したデータを処理します。
  #
  class Handler
    
    #
    # 初期化処理です。
    #
    # ==== Args
    # _channel_id_ :: データの入力元を表す識別子
    # _archive_path_ :: アーカイブ先ディレクトリ
    # _mode_ :: 動作モード(0:通常 1:訓練 2:試験)
    # _need_checksum_ :: チェックサムの実施有無(true:チェックサム実施 false:チェックサム実施なし)
    # ==== Return
    # ==== Raise
    def initialize(channel_id, archive_path, mode, need_checksum)
      @channel_id = channel_id
      @archive_path = archive_path
      @mode = mode
      @need_checksum = need_checksum
      @log = Mrsss.server_logger
    end
    
    #
    # 受信データ処理を行います。データをヘッダ部とボディ部に分割しヘッダ部を解析します。
    #
    # ====Args
    # _message_ :: 受信データ
    # ==== Return
    # ==== Raise
    def handle(message)
      
      # キューに登録するデータ本文
      contents = nil
      
      # BCHの有の電文の場合はBCHを解析して本文部分を抽出
      if message.exist_bch?
        @log.debug("[#{@channel_id}] BCHが存在する電文のためBCH解析実施")
        # BCHとTCH解析
        message.analyze_bch
        
        # BCH解析後の本文データを取得
        contents = message.contents
        
        str_log = "[#{@channel_id}] BCH解析結果\n"
        str_log = "#{str_log}--------------------------------------------------------------------------------\n"
        str_log = "#{str_log}* バージョン      [#{message.bch_version}]\n"
        str_log = "#{str_log}* ヘッダ長        [#{message.bch_length}]\n"
        str_log = "#{str_log}* XML種別         [#{message.bch_xml_type}]\n"
        str_log = "#{str_log}* A/N桁数         [#{message.bch_anlength}]\n"
        str_log = "#{str_log}* チェックサム    [#{message.bch_checksum}]\n"
        str_log = "#{str_log}--------------------------------------------------------------------------------"
        @log.info(str_log)
        
        # BCHバージョン1以外はチェックサム実施
        unless message.bch_version != 1
          # 設定ファイルでチェックサム実施フラグがONの場合はチェックサム実施
          if @need_checksum == true
            # チェックサム実施
            unless message.checksum
              @log.error("[#{@channel_id}] チェックサムエラーのため処理を中断します")
              return nil
            end
          end
        end
        # 本文部分がgzip or zip圧縮されている場合は解凍する
        # tarファイルなどそれ以外の場合はそのまま使用
        # gzip圧縮
        if message.bch_xml_type == 2
          @log.debug("[#{@channel_id}] gzip圧縮された電文のためgzip解凍")
          contents = Util.ungzip(contents)
        # zip圧縮
        elsif message.bch_xml_type == 3
          @log.debug("[#{@channel_id}] zip圧縮された電文のためzip解凍")
          contents = Util.unzip(contents)
        end
      else
        @log.debug("[#{@channel_id}] BCHが存在しない電文のためBCH解析を行わない")
        # BCH無しの場合はJmaMessageのユーザデータ部全てが本文部
        contents = message.userdata
      end
      
      # アーカイブ保存
      # 拡張子を決定する
      ext = ''
      file_format = ''
      if message.message_type == 'JL'
        ext = 'tar'
        file_format = 'TXT'
      elsif message.bch_xml_type == 1 || message.bch_xml_type == 2 || message.bch_xml_type == 3
        ext = 'xml'
        file_format = 'XML'
      end
      Util.archive(contents, @archive_path, ext)
      
      # message_typeが'JL'の場合はtarファイルのためtarファイルを解凍する
      # このtarファイル内のテキストデータはShift_JIS文字コードのため
      # resque登録時に文字化けが発生する
      # そのためresque登録前にテキストファイル形式に変換しておく
      if message.message_type == 'JL'
        @log.debug("[#{@channel_id}] メッセージ種別が[JL]のためtarファイルを解凍する")
        contents = Util.untar(contents)
      end

      # キューに登録する(キューはresqueを使用)
      str_log = "[#{@channel_id}] 受信データをキューへ登録\n"
      str_log = "#{str_log}--------------------------------------------------------------------------------\n"
      str_log = "#{str_log}* 通常/訓練/試験モード  [#{@mode}]\n"
      str_log = "#{str_log}* チャネルID [#{@channel_id}]\n"
      str_log = "#{str_log}* ファイル形式 [#{file_format}]\n"
      str_log = "#{str_log}--------------------------------------------------------------------------------"
      @log.info(str_log)
      
			begin
        Resque.enqueue(Mrsss::Parsers::Parser, contents, @mode, @channel_id, file_format)
      rescue => exception
        @log.error("受信データのキュー登録に失敗しました。")
        @log.error(exception)	
      end
    end
    
  end # Handler

end # Mrsss