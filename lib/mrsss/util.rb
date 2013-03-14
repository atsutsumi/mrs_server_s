module Mrsss
  # Utility methods for Lgdisit module
	module Util

		# Retrieves a parent directory path
		# ==== Args
		# _file_path_ :: a file path to get a parent path
		# ==== Return
		# returns the parent path		
		def self.get_config_path(file_path)
			@config_path ||= File.join(get_parent_path(file_path), "config")
			return @config_path
		end

		# Retrieves a path of the directory that contains configuration files 
		# Assumes the relative path of the directory from this module is "../config"
		# ==== Args
		# _file_path_ :: a file path to get the directory path which contains configuration files
		# ==== Return
		# returns the configuration file path		
		def self.get_parent_path(file_path)
			@parent_path ||= File.dirname(File.dirname(File.expand_path(file_path)))
			return @parent_path
		end

		# Retrieves yaml configuration hash values
		# ==== Args
		# yaml file name
		# ==== Return
		# configuration hash values
		def self.get_yaml_config(config_file_name)
				yaml_config ||= YAML.load(File.open(File.join(get_config_path(__FILE__), config_file_name)))
				return yaml_config
		end
		
    #
    # バイト配列(String)がzipファイルの場合に解凍し内容をStringで返却
    #
    def self.unzip(str)
      Zip::Archive.open_buffer(str) do |archive|
        archive.each do |entry|
          contents entry.read
        end
      end
      return contents
    end
    
    #
    # バイト配列(String)がgzipファイルの場合に解凍し内容をStringで返却
    #
    def self.ungzip(str)
      sio = StringIO.new(str)
      contents = Zlib::GzipReader.wrap(sio).read
      return contents
    end

    #
    # アーカイブファイルを保存する
    #
    def self.archive(contents, archive_path, ext)
      
      # 現在日時.<拡張子>の形式でファイル名を作成
      now = Time.now
      file_name = now.strftime("%Y%m%d_%H%M%S") + '.' + ext
      
      # ファイル保存
      File.binwrite(File.join(archive_path, file_name), contents)
    end

	end
end
