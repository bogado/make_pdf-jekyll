require "make_pdf/command_based"

module MakePDF
  class Chrome < CommandBased::Writer
    COMMAND = 'chrome-headless-render-pdf'

    def initialize(source_url, output_dir, **options)
      super(source_url, output_dir, command: COMMAND, **options)
    end
  end
end
