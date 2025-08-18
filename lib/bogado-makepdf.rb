# frozen_string_literal: true

require 'jekyll'
require 'selenium-webdriver'
require 'fileutils'
require 'pathname'

module Bogado
  COMMAND = 'chrome-headless-render-pdf'

  module Arguments
    attr_reader :base

    def make_arguments(options = [], **more)
      options.concat(more.map { |key, value| "#{self.class.prefix}#{key}#{"=#{value}" unless value == true || value.nil?}" })
    end
  end

  class PdfWriter
    attr_reader :output, :url
    def initialize(url, output, **options)
      @url = url
      @output = output
      @options = options
    end

    def render(file, **version)
      options = @options.merge(version)
      render_pdf(url(file, **options), output_for(file, **options), **options)
    end
  end

  class CommandWriter < PdfWriter
    attr_reader :command, :options
    include Arguments

    def self.prefix
      '--'
    end

    def initialize(url, output, command: COMMAND, **options)
      super(url, output)
      @command = command
      @options = options
    end

    def render_pdf(url, output, **options)
      Jekyll.logger.info("pdf-writer (#{command}): converting #{url}")

      arguments = make_arguments(command: @command, url: url, pdf: output)
      IO.popen([@command] + arguments, {:err =>[ :child, :out]}) do |pipe| 
        output = pipe.read
      end

      raise output if ($? != 0)
      Jekyll.logger.info("pdf-writer (#{command}): Wrote #{output}")
    end

    def relative_path(file, base_path)
      file = Pathname.new(file) unless file.instance_of?(Pathname)
      Pathname.new(file.relative_path_from(base_path)).dirname
    end

    def url(file, base_path:, base_url: "file:/", version: [], **options)
      file_path = Pathname.new(file) unless file.instance_of?(Pathname)

      option = unless version.empty? 
                 "##{version.join(",")}"
               else
                 ""
               end 
      "#{base_url}#{relative_path(file_path, base_path)}/#{file_path.basename}#{option}"
    end

    def output_for(file, base_path:, output: nil, version: [], **options)
      if @output.nil?
        path = File.dirname(file)
      else
        path = File.expand_path(relative_path(file, base_path), @output)
      end

      FileUtils.mkdir_p path

      suffix = if version.empty? then "" else "_#{version.join("_")}" end
      File.expand_path(File.basename(file, ".html") + "#{suffix}.pdf", path)
    end
  end

  class FirefoxPDFWriter
    include Arguments

    def self.prefix
      '-'
    end

    def initialize(options)
      Jekyll.logger.info('MakePDF firefox:', options)
      @args = make_arguments(**options)
      @driver_opts = Selenium::WebDriver::Firefox::Options.new(args: @opts)
      setup
    end

    def setup
      Jekyll.logger.info('MakePDF firefox: start driver')
      @driver = Selenium::WebDriver.for :firefox, capabilities: @driver_opts
    end

    def pdf_new(url, output)
      @driver.get(url)
      @driver.save_print_page output
    end
  end

  # MakePDF plugin
  class MakePDF
    class << self
      attr_reader :file, :site, :current_doc, :options, :command, :output

      def setup(current_doc)
        if @site.nil?
          @site ||= current_doc.site

          @options             = @site.config['make-pdf'] || {}
          @options['command'] |= COMMAND
          @writer = if @options.has_key?('writer') then
            Bogado.const_get(@options['writer'].to_sym) 
          else
            CommandWriter
          end

          @opt_in      = @options['write-by-default'] || false
          @base_url    = @options['source'] || "file:/"

          return false if @options['writer'] == "none"
          @base_source = @site.dest
          Jekyll.logger.debug("Initialized pdf-writer with #{@options}. #{@base_source}")
        end

        @output = @options['output']
        file   = current_doc.destination(@base_source)

        return false if @command == 'skip'
        return false if File.extname(file) != '.html'
        return false if current_doc.data['make-pdf'].nil? && !@opt_in
        return false if current_doc.data['make-pdf'] == false
        return false if @writer.nil?

        Jekyll.logger.info("MakerPDF file: #{file.to_s}")

        @writer.new(file, output, **@options)
      end

      def make(current_doc)
        writer = setup(current_doc)

        return if writer === false

        options = current_doc.data['targets']&.split(';') || []
        file = current_doc.destination(@site.dest)

        writer.render(file, base_path: @site.dest, base_url: @base_url)
        options.each { |option| writer.render(file, base_path: @site.dest, base_url: @base_url,  version: option.split(",")) }
      end

      def relative_path(file)
        File.dirname(file).sub(/^#{@base_source}\//, "")
      end

      def render_option(file, option = [])
        Jekyll.logger.debug('MakePDF options:', option)

        raise "File #{file} is not accessible" unless File.readable?(file)

        attempted = 0
        options = @options.merge { "version" => option }

        begin
          @writer.pdf_new(url, output_path, options)
        rescue => error
          attempted += 1
          if attempted <= 2
            Jekyll.logger.warn("MakePDF: Failed to generate #{file} retrying #{attempted}")
            Jekyll.logger.warn("MakePDF: ERROR: #{error}")
            retry
          else
            Jekyll.logger.error("MakePDF: Skipping generation of #{file} with #{option}")
            raise error
          end
        end
      end
    end
  end
end

Jekyll.logger.info('loaded')
Jekyll::Hooks.register [:pages, :documents, :posts], :post_write do |doc|
  Bogado::MakePDF.make(doc)
end

