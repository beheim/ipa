require 'zip/zip'
require 'zip/zipfilesystem'
require 'cfpropertylist'

module IPA
	class IPAFile
		MAPPED_INFO_KEYS = {
			:name           => 'CFBundleName',
			:display_name   => 'CFBundleDisplayName',
			:identifier     => 'CFBundleIdentifier',
			:icon_path      => 'CFBundleIconFile',
			:icon_paths     => 'CFBundleIconFiles',
			:is_iphone      => 'LSRequiresIPhoneOS',
			:app_category   => 'LSApplicationCategoryType',
			:version        => 'CFBundleVersion',
			:version_string => 'CFBundleShortVersionString',
			:minimum_os_version => 'MinimumOSVersion',
			:device_family      => 'UIDeviceFamily'
		}

		MAPPED_INFO_KEYS.each do |method_name, key_name|
			define_method method_name do
				info[key_name]
			end
		end

		def self.open(filename, &block)
			IPAFile.new(filename, &block)
		end

		def initialize(filename, &block)
			@zipfile = Zip::ZipFile.open(filename)
			unless block.nil?
				yield self
				close
			end
		end

		def close
			@zipfile.close
		end

		def payload_path(filename = nil)
			@payload_path ||= File.join('Payload',
				@zipfile.dir.entries('Payload').
				first{ |name| name =~ /\.app$/ })

			filename.nil? ? @payload_path : File.join(@payload_path, filename)
		end

		def payload_file(filename, &block)
			data = @zipfile.read(payload_path(filename))
			yield data unless block.nil?
			data
		end

		def info
			if @info_plist.nil?
				data = payload_file('Info.plist')
				plist = CFPropertyList::List.new(:data => data)
				@info_plist = CFPropertyList.native_types(plist.value)
			end
			@info_plist
		end

    def icons
      paths = nil
      path_keys = ['CFBundleIcons', 'CFBundleIcons~ipad']
      path_keys.each do |path_key|
        paths ||= info && (info[path_key] &&
            info[path_key]['CFBundlePrimaryIcon'] &&
              (info[path_key]['CFBundlePrimaryIcon']['CFBundleIconFile'] ||
                info[path_key]['CFBundlePrimaryIcon']['CFBundleIconFiles']))
      end

      paths ||= 'Icon.png'

      unless paths.is_a?(Array)
        paths = [paths]
      end

      paths = paths.map do |path|
        begin
          @zipfile.entries.entries.map { |e| File.basename(e.name) }.select { |name| name.start_with?(path) }
        rescue Exception => e
          STDERR.puts "\n\nException #{e}\n\n"
          nil
        end
      end.flatten.compact.map do |path|
        [path, Proc.new { payload_file(path) }]
      end

      Hash[paths]
    end

		def artwork
			payload_file('iTunesArtwork')
		end
	end
end
