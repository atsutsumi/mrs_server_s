# coding: UTF-8

module Mrsss
  
  module Parsers
    #
    # Resqueからデータを受信し各データに合わせた解析処理を行う
    #
    class Parser
  
      # 監視対象となるResqueのキュー名称
      @queue = "mrsss"
      
      # I/Fよびだし処理 非同期処理にはResqueを使用
      # ==== Args
      # _contents_ :: 本文
      # _mode_ :: 通常/訓練/試験モード
      # _channel_id_ :: 入力元識別子
      # _file_format_ :: ファイルフォーマット
      # ==== Return
      # _status_ :: 戻り値
      # ==== Raise
      def self.perform(contents, mode, channel_id, file_format)
        
        # ログ設定をロード
        Mrsss.load_log_config
        
        log = Mrsss.parser_logger
        
        log.info('--------------------------------------------------------------------------------')
        log.info('    キューからデータを取得')
        log.info("    file_format -> [#{file_format}]")
        log.info("    channel_id  -> [#{channel_id}]")
        log.info('--------------------------------------------------------------------------------')
        # XMLファイルは解析が必要
        if file_format == 'XML'
          # JMAのXML
          if channel_id == 'JMA' || channel_id == 'JAL'
            handler = JmaXml.new(mode, channel_id)
            handler.handle(contents)
          # 河川のXML
          elsif channel_id == 'KSN'
            handler = KsnXml.new(mode, channel_id)
            handler.handle(contents)
          end
        # TARファイルはアップロードのみ
        elsif file_format == 'TXT'
          handler = Txt.new(mode, channel_id)
          handler.handle(contents)
        # PDFファイルはアップロードのみ
        elsif file_format == 'PDF'
          handler = PDF.new(mode, channel_id)
          handler.handle(contents)
        else
          log.warning("キューから取得したデータのファイルフォーマットが規定外のため処理しません")
        end
        
      end
    
    end # Parser
    
  end # Parsers

end # Mrsss
