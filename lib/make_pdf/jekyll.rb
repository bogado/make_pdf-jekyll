require 'jekyll'
require 'make_pdf'

module MakePDF

  LOG_NAME = "make_pdf:"
  # MakePDF Jekyll plugin
  class Jekyll

    class Logger

      def initialize(logger)
        @logger = logger
      end

      def message(*args, **options)
        @logger.message(LOG_NAME, *args, **options)
      end

      def warn(*args, **options)
        @logger.warn(LOG_NAME, *args, **options)
      end

      def info(*args, **options)
        @logger.info(LOG_NAME, *args, **options)
      end

      def debug(*args, **options)
        @logger.debug(LOG_NAME, *args, **options)
      end
    end

    class << self
      include PathManip
      attr_reader :file, :site, :current_doc, :options, :command, :output

      def setup(current_doc)
        if @site.nil?
          @site        = current_doc.site
          @options     = @site.config['make-pdf'] || {}
          @opt_in      = @options['write-by-default'] || false
          @base_url    = @options['source'] || "file:"
          @base_source = @site.dest
          @logger      = Logger.new(::Jekyll.logger)

          @logger.debug("Initialized with #{@options}. #{@base_source}")
        end

        current_options = @options.merge(current_doc.data)
        @logger.debug(current_options)
        bail = lambda do |error|
          @logger.debug(error)
          false
        end

        writer = current_options['writer']
        return bail.call("No writer defined for #{current_doc.name} (#{writer})") if writer.nil?

        @writer = MakePDF.const_get(current_options['writer'].capitalize)

        file   = current_doc.destination(@base_source)
        output_dir = @options['output_dir'] || path_of(file).dirname

        return bail.call("#{file} is not an html") if File.extname(file) != '.html'
        return bail.call("#{current_doc.name} has not opted in") if current_doc.data['make-pdf'].nil? && !@opt_in
        return bail.call("#{current_doc.name} has opted out")if current_doc.data['make-pdf'] == false

        @logger.info(" processing #{current_doc.name}")

        @writer.new(file, output_dir, base_source: @base_source, logger: @logger, **current_options)
      end

      def process(current_doc)
        writer = setup(current_doc)

        @logger.debug(" Ignoring #{current_doc.destination("")}")
        return if writer === false

        options = current_doc.data['targets']&.split(';') || []
        file = current_doc.destination(@site.dest)

        render_option(writer, file, base_path: @site.dest, base_url: @base_url)
        options.each { |option| render_option(writer, file, base_path: @site.dest, base_url: @base_url,  version: option.split(",")) }
      end

      def render_option(writer, file, **options)
        @logger.debug("MakePDF options: #{options}")

        raise "File #{file} is not accessible" unless File.readable?(file)

        attempted = 0
        
        begin
          writer.write(file, **options)
        rescue => error
          attempted += 1
          if attempted <= 2
            @logger.warn("Failed to generate #{file} retrying #{attempted}")
            @logger.warn("ERROR: #{error}")
            retry
          else
            @logger.warn("Skipping generation of #{file} with #{options}")
            raise error
          end
        end
      end
    end
  end

  ::Jekyll.logger.info(LOG_NAME, "loaded")
  ::Jekyll::Hooks.register [:pages, :documents, :posts], :post_write do |doc|
    MakePDF::Jekyll.process(doc)
  end
end
