require 'fileutils'
require 'pathname'
require 'make_pdf'

module MakePDF
  module CommandBased
    module Arguments
      attr_reader :base

      def make_arguments(options = [], **more)
        options.concat(more.map { |key, value| "#{self.class.prefix}#{key}#{"=#{value}" unless value == true || value.nil?}" })
      end
    end

    class Writer < PDFWriter
      attr_reader :command, :options
      include Arguments

      def self.prefix
        '--'
      end

      def initialize(url, output_dir, command: COMMAND, **options)
        super(url, output_dir, **options)
        @command = command
        @options = options
      end

      def write(source_url, output_filename, base_path:, **options)
        logger.info("converting #{source_url} with #{@command}")
        arguments = make_arguments(
          command: @command,
          source_url:,
          output_filename:,
          **options
        )
        logger.debug("Executing #{@command} #{arguments}")
        std_out = IO.popen([@command] + arguments, {:err =>[ :child, :out]}) do |pipe| 
          pipe.read
        end

        raise std_out if ($? != 0)
        logger.info("pdf-writer (#{command}): Wrote #{output}")
      end

      def output_for(file, base_path:, version: [], **options)
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
  end
end
