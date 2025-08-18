require 'jekyll'
require 'make_pdf'

module MakePDF

  # MakePDF Jekyll plugin
  class Jekyll

    class << self
      include PathManip
      attr_reader :file, :site, :current_doc, :options, :command, :output

      def setup(current_doc)
        if @site.nil?
          @site        = current_doc.site
          @options     = @site.config['make-pdf'] || {}
          @opt_in      = @options['write-by-default'] || false
          @base_url    = @options['source'] || "file:/"
          @base_source = @site.dest

          ::Jekyll.logger.debug("make_pdf:", "Initialized with #{@options}. #{@base_source}")
        end
          
        current_options = @options.merge(current_doc.data)
        ::Jekyll::logger.debug("make-pdf", current_options)
        bail = lambda do |error|
          ::Jekyll.logger.debug("make_pdf:", error)
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

        ::Jekyll.logger.info("make_pdf:", " processing #{current_doc.name}")

        @writer.new(file, output, logger: ::Jekyll.logger, **current_options)
      end

      def process(current_doc)
        writer = setup(current_doc)

        ::Jekyll::logger.debug("make_pdf:", " Ignoring #{current_doc.destination("")}")
        return if writer === false

        options = current_doc.data['targets']&.split(';') || []
        file = current_doc.destination(@site.dest)

        render_option(writer, file, base_path: @site.dest, base_url: @base_url)
        options.each { |option| render_option(writer, file, base_path: @site.dest, base_url: @base_url,  version: option.split(",")) }
      end

      def render_option(writer, file, **options)
        ::Jekyll.logger.debug('MakePDF options:', options)

        raise "File #{file} is not accessible" unless File.readable?(file)

        attempted = 0
        begin
          writer.write(file, **options)
        rescue => error
          attempted += 1
          if attempted <= 2
            ::Jekyll.logger.warn("MakePDF: Failed to generate #{file} retrying #{attempted}")
            ::Jekyll.logger.warn("MakePDF: ERROR: #{error}")
            retry
          else
            ::Jekyll.logger.error("MakePDF: Skipping generation of #{file} with #{options}")
            raise error
          end
        end
      end
    end
  end

  ::Jekyll.logger.info('MakePDF:', "loaded")
  ::Jekyll::Hooks.register [:pages, :documents, :posts], :post_write do |doc|
    MakePDF::Jekyll.process(doc)
  end
end
