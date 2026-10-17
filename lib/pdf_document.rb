require 'fileutils'
require 'pathname'
require 'uri'

module MakePDF
  module PathObject
    def path_from(obj)
      return Pathname(".") if obj.nil?

      return Pathname.new(obj) if obj.respond_to?(:to_path) || obj.respond_to?(:to_str)
      return Pathname.new(obj.to_s) if obj.is_a?(Integer)

      raise TypeError, "Cannot create path segment from `#{obj.class}`"
    end

    def join_paths(front, *paths)
      path_from(front).join(*paths.map { |p| path_from(p) })
    end

    module_function :path_from, :join_paths

    attr_reader :path

    def initialize(*parts, **_opts)
      @path = join_paths(*parts)
    end

    def to_path
      root / path
    end

    def valid?
      false
    end

    def host
      root.host
    end

    def scheme
      root.scheme
    end

    def root
      raise NotImplementedError, "#{self.class} must implement #root"
    end

    def to_url
      URI::Generic.build(scheme: scheme, host: host, path: to_path.to_s)
    end
  end

  module FileSystemObject
    include PathObject

    attr_reader :root

    def initialize(*_args, root:, host: 'localhost', **options)
      super
      @root = root
      @host = host
    end

    def valid?
      to_path.exist?
    end

    def scheme
      return "file"
    end
  end

  module HttpObject
    include PathObject

    attr_reader :host

    def initialize(*_args, insecure_connection: false, host: 'localhost', **options)
      super
      @secure = not insecure_connection
      @host = host
    end

    def is_secure?
      @secure
    end

    def scheme = "http#{is_secure? ? 's':''}"
  end

  module Readable
    def read(&block)
      return to_enum(:read) unless block_given?

      if scheme == "file"
        to_path.open("r") { |io| io.each_line(&block) }
      else
        URI.open(to_url) { |io| io.each_line(&block) }
      end
    end
  end

  module Writable
    def write(&block)
      create unless is_valid?

      to_path.write('w', &block)
    end
  end

  class RootDir
    include FileSystemObject

    def valid?
      super and to_path.directory?
    end

    def create
      return if valid
      to_path.mkpath
    end
  end

  class SourceFile
    include FileSystemObject
    include Readable

    def valid? = super && to_path.file?

    def read(&block) = to_path.open('r', &block)
  end

  class TargetFile < SourceFile
    include Writable

    def create()
      root.create if not root.valid?

      FileUtils.touch(to_path)
    end

    def write(&block)
      create unless valid? # This may create the root dir also.

      to_path.open('w', &block)
    end
  end
end
