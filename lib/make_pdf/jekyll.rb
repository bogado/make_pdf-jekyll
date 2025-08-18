require 'jekyll'

module MakePDF

  # MakePDF Jekyll plugin
  class Jekyll
    class << self
      attr_reader :file, :site, :current_doc, :options, :command, :output

      def setup(current_doc)
        if @site.nil?
          @site        = current_doc.site
          @options     = @site.config['make-pdf'] || {}
          @opt_in      = @options['write-by-default'] || false
          @base_url    = @options['source'] || "file:/"
          @base_source = @site.dest

          ::Jekyll.logger.debug("Initialized pdf-writer with #{@options}. #{@base_source}")
        end
          
        current_options = @options.merge(current_doc.data)

        writer = current_options['writer']
        return false if writer.nil? || writer.downcase == "none"

        @writer = MakePDF.const_get(current_options['writer'].captilize)

        file   = current_doc.destination(@base_source)
        output_dir = @options['output_dir'] || path_for(file).dirname

        return false if File.extname(file) != '.html'
        return false if current_doc.data['make-pdf'].nil? && !@opt_in
        return false if current_doc.data['make-pdf'] == false
        return false if @writer.nil?

        ::Jekyll.logger.info("MakerPDF file: #{file.to_s}")

        @writer.new(file, output, logger: ::Jekyll.logger, **current_options)
      end

      def process(current_doc)
        writer = setup(current_doc)

        return if writer === false

        options = current_doc.data['targets']&.split(';') || []
        file = current_doc.destination(@site.dest)

        render_option(file, base_path: @site.dest, base_url: @base_url)
        options.each { |option| writer.process(file, base_path: @site.dest, base_url: @base_url,  version: option.split(",")) }
      end

      def render_option(file, **options)
        ::Jekyll.logger.debug('MakePDF options:', options)

        raise "File #{file} is not accessible" unless File.readable?(file)

        attempted = 0
        begin
          @writer.write(url, options:)
        rescue => error
          attempted += 1
          if attempted <= 2
            ::Jekyll.logger.warn("MakePDF: Failed to generate #{file} retrying #{attempted}")
            ::Jekyll.logger.warn("MakePDF: ERROR: #{error}")
            retry
          else
            ::Jekyll.logger.error("MakePDF: Skipping generation of #{file} with #{option}")
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
