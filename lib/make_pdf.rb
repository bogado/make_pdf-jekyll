# frozen_string_literal: true

require 'fileutils'
require 'path_of'

require_relative "./pdf_logger.rb"

module MakePDF
  module PathManip

    def relative_path(file, base_path)
      path_of(file).relative_path_from(path_of(base_path))
    end
  end

  class PDFWriter
    include PathManip
    attr_reader :output_dir, :source_url, :logger

    def initialize(input_base_url:, output_base_path:, output_name: nil, input_scheme: "file", input_host: nil, logger: PdfLogger.new(self.class.name) ,**options)
      @logger = logger
      raise ArgumentError.new("Scheme `#{input_scheme}` requires an `input_host`.") if input_scheme != "file" && input_host.nil?
      @options = options.merge({ input_base_url:, output_base_path:, input_scheme:, input_host:, output_name: output_name || make_pdf_filename(input_base_url) })
    end
 
    def make_relative_file(file, input_location:, **options)
      path_of(file).relative_path_from(path_of(input_location))
    end

    def make_source_url(file, input_base_url:, output_base_path:, input_scheme: , input_host: , input_location:, **options)
      target_file = make_relative_file(file, input_location:, **options)
      input_location = path_of(input_location)
      input_base_url = relative_path_of(input_base_url)
      if (input_scheme != "file")
        return input_scheme + "://" + input_host + "/" + (input_base_url / target_file).to_path
      else
        return (input_location / input_location / target_file).to_path
      end
    end

    def make_pdf_filename(file, output_base_path:, input_location:, output_name:, output_dir:, **options)
      base_path = path_of(output_base_path)
      filepath = make_relative_file(path_of(file).dirname, input_location:)
      result = base_path / relative_path_of(output_dir) / filepath / output_name
      @logger.verbose("make_pdf_filename(#{file}, #{output_base_path}) → base_path: #{base_path}, filepath: #{filepath} ⇒ #{result}")
      result
    end

    def make_output_filename(file, input_location:, output_base_path:, output_name:, output_dir: ".", **options)
      @logger.verbose("make_output_filename(#{file}, #{input_location}, #{output_base_path})")
      filename = make_pdf_filename(file, output_base_path:, output_dir:, output_name:, input_location:,  **options) 
      output_base_path = path_of(output_base_path)
      output = output_base_path / relative_path_of(output_dir) / filename
      
      FileUtils::mkdir_p(output.dirname) unless (output.dirname.directory?)

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
  require file
end
