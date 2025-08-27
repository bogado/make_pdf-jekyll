require 'fileutils'
require 'pathname'
require 'make_pdf'

module MakePDF
  module CommandBased
    module Arguments
      attr_reader :base

      def make_arguments(*options, **more)
        [ 
          options.map { |val| val.to_s },
          more
          .transform_keys { |key| key.to_s.gsub('_','-') }
          .filter_map do |key, value|
            map_option_key(key, value.to_s)
          end
        ].flatten
      end
    end

    class Writer < PDFWriter
      attr_reader :command, :options
      include Arguments

      def self.prefix
        '--'
      end

      def initialize(command: COMMAND, **options)
        super(**options)
        @command = command
      end

      def write(source_url, output_filename, **options)
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
        status = $?
        raise RuntimeError.new("Failure executing #{command} with #{arguments}.\n\noutput:\n\n---\n#{std_out}\n---\n") if status != 0
        logger.info("pdf-writer: Wrote #{output_filename}")
      end

      def output_for(file, output_base_path: ".", version: [], **options)
        output_base_path = Pathname.new(output_base_path)
        file = Pathname.new(file)

        if @output_dir.nil?
          path = output_base_path / file.dirname
        else
          path = File.expand_path(relative_path(file, output_base_path), @output_dir)
        end

        FileUtils.mkdir_p path

        suffix = if version.empty? then "" else "_#{version.join("_")}" end
        File.expand_path(File.basename(file, ".html") + "#{suffix}.pdf", path)
      end
    end
  end
end
