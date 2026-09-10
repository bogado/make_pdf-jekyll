require 'jekyll'
require 'make_pdf'
require 'path_of'
require 'digest'
require 'uri'

require_relative '../pdf_logger.rb'

module MakePDF
  LOG_NAME = 'make_pdf:'.freeze

  # Site
  #
  # Responible for bridging the configurartions on Jekyll and setting up
  # the conversion of PDFs
  class MakePDFSite
    include PathManip
    attr_reader :options, :site, :logger, :file

    def default_options
      {
        output_base_path: site.dest,
        input_location: path_of(site.dest),
        input_base_url: relative_path_of(site.baseurl[1..]),
        input_host: URI(site.config['url']).host,
        input_scheme: 'file'
      }.freeze
    end

    def make_options(options, *more_options)
      return {} if options.nil?

      [options, more_options].flatten
                             .reduce(:merge)
                             .transform_keys do |key|
                               key.to_s.sub('-', '_').to_sym
                             end
    end

    def initialize(site, **options)
      raise 'site is nil' if site.nil?

      @site    = site
      config   = site.config['make-pdf'] || {}
      @logger  = MakePDF::PdfLogger.new(logger: ::Jekyll.logger, level: config['log-map-level'].to_sym || :warn, name: LOG_NAME)
      @options = default_options.merge(make_options(@site.config['make-pdf'], options))
      @queue   = []
      @hashes  = YAML::safe_load_file(metadata_file)

      logger.verbose("Initialized with #{self.options}.")
    end

    def queue(processor)
      @queue.push(processor)
    end

    def <<(doc)
      processor = Processor.new(self, doc, **@options)
      if processor.valid?
        logger.debug("Adding #{processor.name} to queue")
        queue(processor)
      else
        logger.verbose("Skip #{doc.name} => #{processor.reason}")
      end
    end

    def metadata
      'make_pdf_hashes'
    end

    def metadata_dir
      result = Pathname.new(site.config['data_dir'])
      Dir.mkdir(result) unless Dir.exist?(result)

      result
    end

    def metadata_file
      metadata_dir / Pathname.new("#{metadata}.yaml")
    end

    def save_hashes
      logger.debug("Saving hash file : #{metadata_file}")
      logger.verbose("Hashes: #{@hashes.to_yaml}")
      File.open(metadata_file, 'w') do |file|
        file.write(@hashes.to_yaml)
      end
    end

    def process
      @queue.each do |processor|
        hash = processor.filehash
        if hash != @hashes[processor.source.to_s]
          processor.process(**@options)
          @hashes[processor.source.to_s] = hash
        else
          processor.skip('Not changed')
        end
      end
      save_hashes
    end
  end

  # MakePDF Jekyll plugin
  #
  # Processor is the class that process a single document.
  class Processor
    attr_reader :reason, :doc, :name, :source, :file

    def valid?
      @reason.nil?
    end

    def check_failure(condition, message)
      @reason = message if condition
      condition
    end

    def enable(value)
      possible = {
        '' => true,
        'true' => true,
        'yes' => true,
        'false' => false,
        'no' => false
      }

      ['make-pdf', possible[value.to_s.downcase]]
    end

    def filter_options(document, **options)
      document.data.filter_map do |key, value|
        key = key.to_s
        if key == 'make-pdf'
          enable(value)
        elsif key.start_with?('make-pdf-')
          [key.sub('make-pdf-', '').to_sym, value]
        end
      end.to_h.merge(options)
    end

    def skip(reason)
      logger.info("Skipped #{@file} #{reason}")
    end

    def initialize(site, current_doc, **options)
      @site     = site
      @file     = current_doc.destination(@base_source)
      @options  = filter_options(current_doc, **options)
      @name     = current_doc.name
      @source   = current_doc.path

      logger.debug("base_paths: input → #{@options[:input_base_url]} " \
                   "output → #{@options[:output_base_path]} " \
                   "host → #{@options[:input_host]}")

      current_options = make_options(@options, options, filter_options(current_doc))
      current_options[:output_name] ||= Pathname.new(@name).sub_ext('.pdf')

      logger.debug("options : #{current_options}")

      return if check_failure(current_options[:disabled], 'MakePDF disabled')

      return if check_failure(File.extname(@file) != '.html', "#{@file} is not an html")

      return if check_failure(current_options[:make_pdf].nil? && !@opt_in, "#{current_doc.name} has not opted in")

      return if check_failure(current_options[:make_pdf] == false, "#{current_doc.name} has opted out")

      writer = current_options[:writer] || site.options[:writer]
      return if check_failure(writer.nil?, "No writer defined for #{current_doc.name} (#{writer})")

      @writer = MakePDF.const_get(writer.capitalize).new(logger: logger, **current_options)
      @doc = current_doc
    end

    def output_dir
      @writer.output_dir
    end

    def targets
      @options[:targets] || ''
    end

    def respond_to_missing?(method_name)
      @options.include?(method_name) ||
        (!@site.options.nil? && @site.options.include?(method_name)) ||
        @site.respond_to?(method_name, false)
    end

    def method_missing(method_name, *args, **options)
      if @options.include?(method_name)
        @options[method_name]
      elsif !@site.options.nil? && @site.options.include?(method_name)
        @site.options[method_name]
      elsif @site.respond_to?(method_name, false)
        @site.send(method_name, *args, **options)
      else
        super
      end
    end

    private

    def try(identification, count)
      begin
        yield
      rescue => error
        attempt += 1
        message = "#{identification} attempt number #{attempt} failed with #{error}"
        if attempted < count
          logger.warn("#{message}, retrying")
          retry
        else
          logger.error("#{message}.")
        end
      end
    end

    public

    def render_option(**options)
      logger.info("processing #{@file}")
      logger.debug("MakePDF rendering options #{options}")
      try("Process #{@file}", 3) do
        @writer.process(@file, **options.merge(@options))
      end
    end

    def filehash
      return Digest::SHA256.file(@source).hexdigest
    end

    def process(**options)
      render_option(**options)
      return if targets.nil?

      targets.split(',').each do |option|
        render_option(version: option.split(','), **options)
      end
    end
  end

  ::Jekyll.logger.info("Loaded #{MakePDF::LOG_NAME} plugin")

  ::Jekyll::Hooks.register [:site], :after_init do |site|
    @pdf_site = MakePDF::MakePDFSite.new(site)
    @pdf_site.logger.debug("site :after_init #{@pdf_site}")
  end

  ::Jekyll::Hooks.register [:pages, :documents, :posts], :post_write do |doc|
    @pdf_site << doc
  end

  ::Jekyll::Hooks.register [:site], :post_write do
    @pdf_site.process
  end
end
