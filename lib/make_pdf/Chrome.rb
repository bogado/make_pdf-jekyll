
module MakePdf
  class Chrome < CommandBased::Writer
    COMMAND = 'chrome-headless-render-pdf'

    def initialize(source_url, output_dif, **options)
      super(source_url, output_dif, command: COMMAND, **options)
    end
  end
end
