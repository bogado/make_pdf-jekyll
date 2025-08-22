# frozen_string_literal: true

require 'selenium-webdriver'

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
    def debug(*args)
    end

    alias info debug
    alias warn debug
    alias error debug
  end

  class PDFWriter
    include PathManip
    attr_reader :output_dir, :source_url, :logger

    def initialize(source_url, output_dir, logger: Logger.new() ,**options)
      @source_url = source_url
      @output_dir = path_of(output_dir)
      @logger = logger
      @options = options
    end
    
    def make_source_url(file, base_path:, base_url: nil, **options)
      base_path = Pathname.new(base_path).realpath
      target_file = Pathname.new(file).realpath.relative_path_from(base_path)
      if (base_url != "file:")
        return base_url + target_file.to_s
      else
        return base_path + target_file.to_s
      end
    end

    def make_pdf_filename(file, **options)
      path_of(file).basename.sub_ext(".pdf")
    end

    def make_output_filename(file, base_path:, **options)
      filename = make_pdf_filename(file, base_path:, **options) 
      output = @output_dir / filename
      @logger.debug("filenane : #{filename} output_dir: #{output_dir} output_filename: #{output}")
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
