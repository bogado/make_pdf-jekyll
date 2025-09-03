require 'jekyll'
require 'make_pdf'
require 'path_of'

module MakePDF
  LOG_NAME = "make_pdf:"

  # MakePDF Jekyll plugin
  class Processor
    attr_reader :reason, :doc, :name

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

          [ key, possible[value.to_s.downcase] ]
        else
          [ key.sub("make-pdf-", "").to_sym, value ] if key.start_with?("make-pdf-")
        end
      end.to_h.merge(options)
    end

    def initialize(site, current_doc, **options)
      @site    = site
      @file    = current_doc.destination(@base_source)
      @options = filter_options(current_doc, **options)
      @name    = current_doc.name

      logger.debug("base_paths: input → #{@options[:input_base_url]} output → #{@options[:output_base_path]} host → #{@options[:input_host]}")

      current_options = make_options(@options, options, filter_options(current_doc))

      logger.debug("options : #{current_options}")

      return if check_failure(current_options[:disabled], "MakePDF disabled")

      return if check_failure(File.extname(@file) != '.html', "#{@file} is not an html")

      return if check_failure(current_options[:make_pdf].nil? && !@opt_in, "#{current_doc.name} has not opted in")

      return if check_failure(current_options[:make_pdf] == false, "#{current_doc.name} has opted out")

      writer = current_options[:writer] || site.options[:writer]
      return if check_failure(writer.nil?, "No writer defined for #{current_doc.name} (#{writer})")

      @writer = MakePDF.const_get(writer.capitalize).new(logger:, **current_options)
      @doc = current_doc
    end

    def output_dir
      @writer.output_dir
    end

    def targets
      @options[:targets] || ""
    end

    def method_missing(method_name, *args, **options)
      if @options.include?(method_name)
        return @options[method_name]
      elsif not @site.options.nil? and @site.options.include?(method_name)
        return @site.options[method_name]
      elsif @site.respond_to?(method_name, false)
        return @site.send(method_name, *args, **options)
      else
        super
      end
    end

    def render_option(**options)
      logger.debug("MakePDF rendering options #{options}")

      attempted = 0
      begin
        logger.info("processing #{@file}")
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

    class Site
      include PathManip
      attr_reader :options, :site, :logger

      def default_options
        return { 
          output_base_path: site.source, 
          input_location: path_of(site.dest),
          input_base_url: relative_path_of(site.baseurl[1..]),
          input_host: site.config["url"].match(Regexp.new("^[^:]*://\([^/]+\)/?.*$"))[1],
          input_scheme: "file"
        }.freeze
      end

      def make_options(options, *more_options)
        return {} if options.nil?

        [ options, more_options ].flatten
          .reduce(:merge)
          .transform_keys do |key|
            key.to_s.sub("-", "_").to_sym
          end
      end

      def initialize(site, **options)
        config = site.config["make-pdf"]||{}
        @logger = MakePDF::Logger.new(logger: ::Jekyll.logger, level: (config["log-map-level"] || :debug))
        @site         = site
        @options = default_options.merge(make_options(@site.config["make-pdf"], options))
        @queue        = []
        logger.debug("Initialized with #{self.options}.")
      end

      def queue(processor)
        logger.info("Adding #{processor.name} to queue")
        @queue.push(processor)
      end

      def <<(doc)
        processor = Processor.new(self, doc, **@options)
        if processor.valid?
          queue(processor)
        else
          logger.info("Skip #{doc.name} => #{processor.reason}")
        end
      end

      def process
        @queue.each do |processor|
          processor.process(**@options)
        end
      end
    end
  end

  ::Jekyll.logger.info("Loaded #{MakePDF::LOG_NAME} plugin")

  ::Jekyll::Hooks.register [:site], :after_init do |site|
    @@site = MakePDF::Processor::Site.new(site)
    @@site.logger.info("site :after_init #{@@site}")
  end

  ::Jekyll::Hooks.register [:pages, :documents, :posts], :post_write do |doc|
    @@site << doc
  end

  ::Jekyll::Hooks.register [:site], :post_write do |site|
    @@site.process
  end
end
