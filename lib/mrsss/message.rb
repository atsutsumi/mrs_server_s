# coding: UTF-8

module Mrsss
  
  # JMAソケット通信により受信したデータを解析/保持するクラス
  class Message
    
    # ---------------------------------------------------------------
    # 定数定義
    # ---------------------------------------------------------------
    # メッセージ種別
    MSGTYPE_AN = 'AN' # 文字データ(チェックポイントなし)
    MSGTYPE_BI = 'BI' # バイナリデータ(チェックポイントなし)
    MSGTYPE_FX = 'FX' # FAX図データ(チェックポイントなし)
    MSGTYPE_JL = 'JL' # 内閣官房Tarデータ(チェックポイントなし)
    MSGTYPE_aN = 'aN' # 文字データ(チェックポイントあり)
    MSGTYPE_bI = 'bI' # バイナリデータ(チェックポイントあり)
    MSGTYPE_fX = 'fX' # FAX図データ(チェックポイントあり)
    MSGTYPE_EN = 'EN' # 制御データ
    
    # 制御レコード種別
    CTLTYPE_ACK = 'ACK' # チェックポイント通知
    CTLTYPE_chk = 'chk' # ヘルスチェック要求
    CTLTYPE_CHK = 'CHK' # ヘルスチェック応答
    
    # ヘルスチェック応答
    @@HELTHCHK_RESPONSE = '00000003ENCHK'
    
    # チェックポイント応答のヘッダ部
    @@CHECKPOINT_RESPONSE_HEADER = '00000033ENACK'
    
    # クラス変数へのアクセサ定義
    cattr_reader :HELTHCHK_RESPONSE, :CHECKPOINT_RESPONSE_HEADER
  
    # インスタンス変数のアクセサ定義
    attr_reader :data, :message_length, :message_type, :userdata_length, :control_type, :str_bch
    
    
    # ---------------------------------------------------------------
    # public メソッド
    # ---------------------------------------------------------------
    #
    # 初期化処理
    #
    def initialize(data)
      # 生データ保存
      @data = data
      
      # JMAソケットヘッダ部の解析
      header = data[0, 10]
      
      # メッセージ長取得
      @message_length = header[0, 8].to_i
      
      # メッセージ種別取得
      @message_type = header[8, 2].to_s
      
      # ユーザデータ長取得
      @userdata_length = data.length - 10
      
      # 制御データの場合はコントロール種別を取得
      if @message_type == MSGTYPE_EN
        @control_type = data[10, 3].to_s
      end
    end
    
    #
    # 引数データを当クラスで保持するデータの最後尾に追加する
    # データが分割して送信される際に使用するメソッド
    #
    def append(data)
      if @data.blank?
        return
      end
      # データを最後尾に連結
      @data = @data + data
      # データ長を再計算
      @userdata_length = @data.length - 10
      self
    end
    
    #
    # チェックポイント応答データを取得する
    #
    def checkpoint_response
      @@CHECKPOINT_RESPONSE_HEADER + @data[0, 30]
    end
    
    #
    # ユーザデータ部を取得するメソッド
    #
    def userdata
      @data[10, (@data.length - 10)]
    end
    
    #
    # データレングスと実際のデータ長の一致判定
    # 
    def complete?
      @message_length == @userdata_length
    end
    
    #
    # ヘルスチェック判定
    #
    def healthcheck?
      @message_type == MSGTYPE_EN && @control_type == CTLTYPE_chk
    end
    
    #
    # チェックポイント判定
    #
    def checkpoint?
      @message_type == MSGTYPE_aN || @message_type == MSGTYPE_bI || @message_type == MSGTYPE_fX
    end
    
    #
    # BCHの有無を判定
    # メッセージ種別により判定する'JL'の場合はBCHなし
    # 上記以外はBCHありと判断する
    #
    def exist_bch?
      !(@message_type == MSGTYPE_JL)
    end
    
    # ---------------------------------------------------------------
    # 以下BCH,TCH,本文部の抽出用メソッド
    # ---------------------------------------------------------------
    #
    # BCH部を解析します
    #
    def analyze_bch
      
      # ユーザデータを対象に処理
      data = userdata
      
      # まずは先頭1バイトのデータを取得
      # 先頭4ビットがBCHバージョン情報で後続4ビットがBCHレングス
      bch_head1 = data[0]
      bch_ver_len = to_bit_str(bch_head1)
      
      # BCHレングス取得
      bch_length = bch_ver_len[4, 8].to_i(2) * 4 # BCH仕様より4をかけBCHレングスとする
      
      # BCHビットの文字列表現をインスタンス変数に保存
      tmp_bch = data[0, bch_length]
      @str_bch = to_bit_str(tmp_bch)
      
    end
    
    #
    # バージョン
    #
    def bch_version
      @str_bch[0, 4].to_i(2)
    end
    
    #
    # BCHレングス
    #
    def bch_length
      @str_bch[4, 4].to_i(2) * 4
    end
    
    #
    # XMLタイプ
    #
    def bch_xml_type
      @str_bch[36, 2].to_i(2)
    end
    
    #
    # A/N桁数
    # バイナリ電文の場合のみ設定されている
    #
    def bch_anlength
      @str_bch[72, 8].to_i(2)
    end
    
    #
    # チェックサム
    #
    def bch_checksum
      @str_bch[80, 16]
    end
    
    #
    # TCH部
    #
    def tch
      # BCH後からA/N桁数分がTCH部
      data = userdata
      data[bch_length, anlength]
    end
    
    #
    # 本文部
    #
    def contents
      data = userdata
      data[bch_length + bch_anlength, (@userdata_length - bch_length - bch_anlength)]
    end
    
    #
    # チェックサムを実施
    #
    def checksum
      sum = 0
      # BCHを16桁づつ分割し全て加算
      0.upto(9) {|index|
        # チェックサム部分は加算をスキップ
        next if index == 5
        tmp = @str_bch[index*16, 16]
        sum = sum + tmp.to_i(2)
      }
      
      # 加算結果を32桁の文字列に変換
      sum = format("%.32b", sum)
      
      # 上位16桁が0になるまで上位16桁を下位16桁に加算
      upper = 0
      under = 0
      loop do
        # 上位16桁を取得
        upper = sum[0, 16].to_i(2)
        under = sum[16,16].to_i(2)
        
        break if upper == 0
        
        # 上位16桁と下位16桁を加算
        tmp_sum = upper + under
        
        # 加算結果を32桁の文字列に変換
        sum = format("%.32b", sum)
      end
      
      # 計算されたチェックサム値
      calculated_checksum = format("%16b", ~under&0xFFFF)
      
      # BCH内のチェックサム値と計算されたチェックサム値を比較する
      @checksum == calculated_checksum
    end
    
    # ---------------------------------------------------------------
    # private メソッド
    # ---------------------------------------------------------------
private
    
    #
    # バイナリデータを２進数(bit)表現の文字列に変換
    # 1バイトずつ処理し1バイトを8桁のビット文字列とする
    #
    def to_bit_str(data)
      str = ''
      io = StringIO.new(data)
      io.each_byte { |ch|
        str = str + format("%.8b", ch)
      }
      str
    end
  end # Message

end # Mrsss
