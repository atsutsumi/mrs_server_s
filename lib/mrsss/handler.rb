# coding: UTF-8

module Mrsss

  # JMAソケット通信により受信したデータをキューに登録する
  class Handler
    
    # ---------------------------------------------------------------
    # public メソッド
    # ---------------------------------------------------------------
    #
    # 初期化処理
    #
    def initialize(channel_id, archive_path, mode, need_checksum)
      @channel_id = channel_id
      @archive_path = archive_path
      @mode = mode
      @need_checksum = need_checksum
      @log = Mrsss.logger
    end
    
    #
    # データ解析処理
    # ====Args
    # Message
    #
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
        
        @log.info("-----------------------------------------------------------------------")
        @log.info("    BCH")
        @log.info("    バージョン      [#{message.bch_version}]")
        @log.info("    ヘッダ長        [#{message.bch_length}]")
        @log.info("    XML種別         [#{message.bch_xml_type}]")
        @log.info("    A/N桁数         [#{message.bch_anlength}]")
        @log.info("    チェックサム    [#{message.bch_checksum}]")
        @log.info("-----------------------------------------------------------------------")
        
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
        file_format = 'TAR'
      elsif message.bch_xml_type == 1 || message.bch_xml_type == 2 || message.bch_xml_type == 3
        ext = 'xml'
        file_format = 'XML'
      end
      Util.archive(contents, @archive_path, ext)
      
      # キューに登録する(キューはresqueを使用)
			@log.info("キューへ登録")
			begin
        Resque.enqueue(Mrsss::Parsers::Parser, contents, @mode, @channel_id, file_format)
      rescue => exception
        @log.fatal(exception)	
      end
    end
    
  end # Handler

end # Mrsss