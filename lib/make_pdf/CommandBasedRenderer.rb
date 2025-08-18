require 'fileutils'
require 'pathname'

module MakePdf
  module CommandBased
    module Arguments
      attr_reader :base

      def make_arguments(options = [], **more)
        options.concat(more.map { |key, value| "#{self.class.prefix}#{key}#{"=#{value}" unless value == true || value.nil?}" })
      end
    end

    class Writer < PdfWriter
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

      def write(file, base_path:, **options)
        logger.info("pdf-writer (#{command}): converting #{url}")

        arguments = make_arguments(command: @command, url: source_url*(file, **options), pdf: output_for(file, **options))
        IO.popen([@command] + arguments, {:err =>[ :child, :out]}) do |pipe| 
          output = pipe.read
        end

        raise output if ($? != 0)
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
