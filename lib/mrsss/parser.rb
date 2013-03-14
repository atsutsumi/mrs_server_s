# coding: UTF-8

require_relative 'jma_xml_handler'
require_relative 'ksn_xml_handler'
require_relative 'tar_handler'
require_relative 'pdf_handler'

module Mrsss
  
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
      
      # XMLファイルは解析が必要
      if file_format == 'XML'
        # JMAのXML
        if channel_id == 'JMA' || channel_id == 'JAL'
          handler = JmaXmlHandler.new(mode, channel_id)
          handler.handle(contents)
        # 河川のXML
        elsif channel_id == 'KSN'
          handler = KsnXmlHandler.new(mode, channel_id)
          handler.handle(contents)
        end
      # TARファイルはアップロードのみ
      elsif file_format == 'TAR'
        handler = TarHandler.new(mode, channel_id)
        handler.handle(contents)
      # PDFファイルはアップロードのみ
      elsif file_format == 'PDF'
        handler = PDFHandler.new(mode, channel_id)
        handler.handle(contents)
      end
      
    end

  end # Parser

end # Mrsss