# coding: UTF-8

module Mrsss
  module Parsers
    
    #
    # MrsssアプリケーションにおいてResqueに登録されたデータを監視するワーカープロセスです。
    #
    class Parser
  
      # 監視対象となるResqueのキュー名称
      @queue = "mrsss"
      
      #
      # ワーカー処理開始用メソッドです。
      #
      # ==== Args
      # _contents_ :: 本文
      # _mode_ :: 動作モード(0:通常, 1:訓練, 2:試験)
      # _channel_id_ :: 入力元識別子
      # _file_format_ :: ファイルフォーマット
      # ==== Return
      # _status_ :: 戻り値
      # ==== Raise
      def self.perform(contents, mode, channel_id, file_format)
        
        # ログ設定をロード
        Mrsss.load_log_config
        # ロガーを取得
        log = Mrsss.parser_logger
        
        str_log = "[#{channel_id}] キューからデータを取得\n"
        str_log = "--------------------------------------------------------------------------------\n"
        str_log = "* file_format -> [#{file_format}]\n"
        str_log = "* channel_id  -> [#{channel_id}]\n"
        str_log = "--------------------------------------------------------------------------------"
        log.info(str_log)
        
        # XMLファイルは解析が必要
        if file_format == 'XML'
          # JMAのXML
          if channel_id == 'JMA' || channel_id == 'JAL'
            log.info("[#{channel_id}] JmaのXML用解析処理実施")
            handler = JmaXml.new(mode, channel_id)
            handler.handle(contents)
          # 河川のXML
          elsif channel_id == 'KSN'
            log.info("[#{channel_id}] 河川のXML用解析処理実施")
            handler = KsnXml.new(mode, channel_id)
            handler.handle(contents)
          end
        # TARファイルはアップロードのみ
        elsif file_format == 'TXT'
          log.info("[#{channel_id}] J-Alertの内閣官房Text用解析処理実施")
          handler = Txt.new(mode, channel_id)
          handler.handle(contents)
        # PDFファイルはアップロードのみ
        elsif file_format == 'PDF'
          log.info("[#{channel_id}] JMAのPDF用解析処理実施")
          handler = PDF.new(mode, channel_id)
          handler.handle(contents)
        else
          log.warning("[#{channel_id}] キューから取得したデータのファイルフォーマットが規定外のため処理しません")
        end
        
      end
    
    end # Parser
    
  end # Parsers

end # Mrsss
