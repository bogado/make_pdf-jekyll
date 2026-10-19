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

    module_function :join_paths, :path_from

    attr_reader :path

    def initialize(*parts, root: nil, **_opts)
      raise TypeError, "Root needs to respond to `scheme`" unless root.respond_to?(:scheme) or root.nil?
      @path = join_paths(*parts)
    end

    def to_path
      @path
    end

    def valid?
      false
    end

    def /(other)
      to_path.join(other)
    end

    def to_url
      host = nil
      host = root.host if root.respond_to?(:host)
      URI::Generic.build(scheme: root.scheme, host: host, path: to_path.to_s)
    end
  end

  module RootedPathObject
    include PathObject
    attr_reader :root

    def initialize(*parts, root:, **opts)
      super
      @root = root
    end

    def to_path
      return root / path
    end

    def with_root(new_root)
      self.class.new(path, root: new_root)
    end
  end

  module Readable
    def read(&block)
      return to_enum(:read) unless block_given?

      if root.scheme == "file"
        to_path.open("r") { |io| io.each_line(&block) }
      else
        URI.open(to_url) { |io| io.each_line(&block) }
      end
    end
  end

  module Writable
    def write(&block)
      create unless valid?

      to_path.write('w', &block)
    end
  end

  class RootDir
    include PathObject

    def valid?
      full_path = to_path
      full_path.exist? and full_path.directory?
    end

    def scheme
      return "file"
    end

    def create
      return if valid?
      to_path.mkpath
    end
  end

  class HttpRoot
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

  class SourceFile
    include RootedPathObject
    include Readable

    def valid?
      root.valid? && to_path.file?
    end
  end

  class TargetFile < SourceFile
    include Writable

    def with_root(new_root)
      if new_root.scheme.to_s.start_with?("http")
        raise TypeError, "TargetFile cannot be rooted to a remote (#{new_root.scheme}) root"
      end

      super
    end

    def create()
      root.create if not root.valid?

      FileUtils.touch(to_path)
    end
  end
end
