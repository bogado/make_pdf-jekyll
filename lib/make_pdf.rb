# frozen_string_literal: true

require 'fileutils'

module MakePDF
  module PathManip
    def path_of(base, *path_components)
      other = unless path_components.empty?
                path_components
                  .map { |component| path_of(component) }
                  .sum Pathname.new(".")
              else
                Pathname.new("")
              end
      base = Pathname.new(".") if base.nil?
      if base.instance_of?(Pathname) then base else Pathname.new(base) end + other
    end

    def relative_path(file, base_path)
      path_of(file).relative_path_from(path_of(base_path))
    end
  end

  class Logger
    LEVELS = [ :debug, :info, :warn, :error ]

    def level
      @min_level || 0
    end

    def initialize(logger: nil, level: :debug, verbose: false)
      @logger = logger
      @min_level = LEVELS.index(level) || 2
      @verbose = verbose
      write(:debug, "logging at least level #{LEVELS[@min_level].to_s} with #{logger}")
    end

    def write(level, *args)
      print("#{level.to_s} : ", *args.map do |msg|
        if (msg.size > 80)
          msg[0..79] + "…"
        else
          msg
        end
      end.join("\n"), "\n")
      return
    end

    def verbose(*args)
      if (@verbose)
        @logger.send(LEVELS[self.level], LOG_NAME, *args)
      end
    end

    def method_missing(method_name, *args, **options)
      if @logger.nil? and LEVELS.include?(method_name)
        return write(method_name, *args)
      end

      if accepts?(method_name)
        @logger.send(LEVELS[[LEVELS.index(method_name), self.level].max], LOG_NAME, *args, **options)
      else
        super
      end
    end

    def accepts?(method_name)
      LEVELS.include?(method_name) and @logger.respond_to?(method_name, false) 
    end

    def respond_to_missing?(method_name, include_private = false)
      accepts?(method_name) || super
    end
  end

  class PDFWriter
    include PathManip
    attr_reader :output_dir, :source_url, :logger

    def initialize(input_base_path:, output_base_path:, input_scheme: "file", logger: Logger.new() ,**options)
      @logger = logger
      @options = options.merge({ input_base_path:, output_base_path:, input_scheme: })
    end
    
    def make_source_url(file, input_base_path:, output_base_path:, input_scheme: , **options)
      target_file = relative_path(file, input_base_path:, **options)
      if (input_scheme != "file")
        return input_scheme + "://" + output_base_path + target_file.to_s
      else
        return input_base_path + target_file.to_s
      end
    end

    def relative_path(file, input_base_path:, **options)
      base_path = Pathname.new(input_base_path)
      result = Pathname.new(file).relative_path_from(base_path).dirname
      @logger.verbose("relative_path(#{file}, #{input_base_path}) → base_path: #{base_path} ⇒ #{result}")
      result
    end

    def make_pdf_filename(file, input_base_path:, **options)
      base_path = relative_path(file, input_base_path:, **options)
      filename = Pathname.new(file).basename.sub_ext(".pdf")
      result = base_path / filename
      @logger.verbose("make_pdf_filename(#{file}, #{input_base_path}) → base_path: #{base_path}, filename: #{filename} ⇒ #{result}")
      result
    end

    def make_output_filename(file, input_base_path:, output_base_path:, output_dir: ".", **options)
      @logger.verbose("make_output_filename(#{file}, #{input_base_path}, #{output_base_path})")
      filename = make_pdf_filename(file, input_base_path:, **options) 
      output_base_path = Pathname.new(output_base_path)
      output = output_base_path / Pathname.new(output_dir) / filename
      FileUtils::mkdir_p(output.dirname)
      @logger.debug("filename: #{filename} ⇒ #{output}")
      output
    end

    def process(file, version: [], **options)
      options = @options.merge(options)
      output_filename = make_output_filename(file, version: version, **options)
      write(
        make_source_url(file, vesrsion: version, **options),
        output_filename,
        **options
      )
      output_filename
    end
  end
end

Dir[File.join(__dir__, 'make_pdf/', '**', '*.rb')].each do |file| 
  print "#{file}\n"
  require file
end
