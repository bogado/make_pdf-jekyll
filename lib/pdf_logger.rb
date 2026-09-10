require 'jekyll'

module MakePDF
  class PdfLogger
    LEVELS = {
      verbose: :debug,
      debug:   :debug,
      info:    :info,
      warn:    :warn,
      error:   :error,
      fatal:   :error,
      unknown: :error
    }.freeze

    def level
      @min_level || 0
    end

    def severity(level)
      keys = LEVELS.keys.to_a

      return keys.index(:unknown) unless keys.include?(level)

      keys.index(level)
    end

    def initialize(logger: nil, level: :warn, name: "")
      @logger = logger || Logger.new(LEVELS[level])
      @min_level = severity(level) || severity(level) 
      @name = name
      write(:debug, "logging at least level #{LEVELS[@min_level].to_s} with #{logger}")
    end

    def write(level, *args)
      return if severity(level) < @min_level

      @logger.write(LEVELS[level], @name, *args.join("\n"))
      return
    end

    def method_missing(method_name, *args, **options)
      if LEVELS.has_key?(method_name)
        return write(method_name, *args)
      end

      if accepts?(method_name)
        @logger.send(LEVELS[[LEVELS.index(method_name), self.level].max], LOG_NAME, *args, **options)
      else
        super
      end
    end

    def accepts?(method_name)
      LEVELS.include?(method_name) and @logger.respond_to?(method_name, false) 
    end

    def respond_to_missing?(method_name, include_private = false)
       accepts?(method_name, include_private) || super
    end
  end
end
