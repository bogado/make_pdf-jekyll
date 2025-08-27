require 'jekyll'
require 'make_pdf'

module MakePDF
  LOG_NAME = "make_pdf:"

  # MakePDF Jekyll plugin
  class Jekyll
    attr_reader :reason

    def valid?
      @reason.nil?
    end

    def check_failure(condition, message)
      @reason = message if condition
      condition
    end

    def filter_options(document, **options)
      document.data.filter_map do |key, value|
        key = key.to_s
        if key == "make-pdf"
          possible = {
            "" => true,
            "true" => true,
            "yes" => true,
            "false" => false,
            "no" => false
          }

          [ key, possible[value.downcase] ]
        else
          [ key.sub("make-pdf-", "").to_sym, value ] if key.start_with?("make-pdf-")
        end
      end.to_h.merge(options)
    end

    def initialize(current_doc, **options)
      @file     = current_doc.destination(@base_source)
      @options = filter_options(current_doc, **options)
      logger.debug("base_paths: input → #{@options[:input_base_path]} output → #{@options[:output_base_path]}")

      current_options = make_options(@options, site_options, filter_options(current_doc))
      output_dir = @options[:output_dir] || path_of(site.dest).dirname

      logger.debug("options : #{current_options}")

      return if check_failure(File.extname(@file) != '.html', "#{@file} is not an html")
      return if check_failure(current_options[:make_pdf].nil? && !@opt_in, "#{current_doc.name} has not opted in")
      return if check_failure(current_options[:make_pdf] == false, "#{current_doc.name} has opted out")

      writer = current_options[:writer]
      return if check_failure(writer.nil?, "No writer defined for #{current_doc.name} (#{writer})")

      logger.info(" processing #{current_doc.name}")
      @writer = MakePDF.const_get(writer.capitalize).new(logger:, **current_options)
    end

    def targets
      @options[:targets] || ""
    end

    def method_missing(method_name, *args, **options)
      if not Jekyll.site_options.nil? and Jekyll.site_options.include?(method_name)
        return Jekyll.site_options[method_name]
      elsif Jekyll.respond_to?(method_name, false)
        return Jekyll.send(method_name, *args, **options)
      else
        super
      end
    end

    def render_option(**options)
      logger.debug("MakePDF rendering options #{options}")

      attempted = 0
      begin
        @writer.process(@file, **options.merge(@options))
      rescue => error
        attempted += 1
        if attempted <= 2
          logger.warn("Failed to generate #{@file} retrying #{attempted}")
          logger.warn("ERROR: #{error}")
          retry
        else
          logger.warn("Skipping generation of #{@file} with #{options}")
          raise error
        end
      end
    end

    def process(**options)
      render_option(**options)
      unless self.targets.nil?
        self.targets.split(",").each do |option|
          render_option(version: option.split(","), **options)
        end
      end
    end

    class << self
      include PathManip
      attr_reader :site_options, :site

      def make_options(options, *more_options)
        return {} if options.nil?

        [ options, more_options ].flatten
          .reduce(:merge)
          .transform_keys do |key|
            key.to_s.sub("-", "_").to_sym
          end
      end

      def logger(**options)
        @logger ||= MakePDF::Logger.new(**options)
      end

      def setup(site, **options)
        return unless @site.nil?

        config = site.config["make-pdf"]||{}
        logger(logger: ::Jekyll.logger, level: (config["log-map-level"] || :debug).to_sym, verbose: config['log-verbose'])
        @site         = site
        @site_options = { 
          :output_base_path => site.source, 
          :input_base_path => site.dest,
          :input_scheme => "file"
        }.merge(make_options(@site.config["make-pdf"], options))
        logger.debug("Initialized with #{self.site_options}.")
      end

      def process(current_doc, **options)
        setup(current_doc.site, **options) if @site.nil?

        processor = self.new(current_doc)

        unless processor.valid?
          logger.debug "Ignoring #{current_doc.name} ⇒ #{processor.reason}"
          return false
        end

        processor.process(**@site_options)
      end
    end
  end
end

::Jekyll.logger.info("Loaded #{MakePDF::LOG_NAME} plugin")
::Jekyll::Hooks.register [:pages, :documents, :posts], :post_write do |doc|
  MakePDF::Jekyll.process(doc)
end
