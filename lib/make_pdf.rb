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

    def source_url(file, base_path:Pathname.new("."), base_url: "file:/", version: [], separator: ",", **options)
      file_path = path_of(file)

      options = unless version.empty? 
                  "##{version.join(separator)}"
                else
                  ""
                end 
      "#{base_url}#{relative_path(file_path, base_path)}/#{file_path.basename}#{options}"
    end

    def output_for(file, version, **options)
      output = path_of(file).basename(".pdf").to_s
      path_of(@output_dir, output + version.join("_") + ".pdf")
    end

    def process(file, version: [], **options)
      options = @options.merge(options)
      write(
        source_url(file, vesrsion: version, **options),
        output_for(file, version: version, **options),
        **options
      )
    end
  end

end

Dir[File.join(__dir__, 'make_pdf/', '**', '*.rb')].each do |file| 
  print "#{file}\n"
  require file
end
