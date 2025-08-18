
# TODO: In progress.
# Firefox css media don't work well anyway.
#
module MakePdf
  class FirefoxPDFWriter
    include Arguments

    def self.prefix
      '-'
    end

    def initialize(options)
      Jekyll.logger.info('MakePDF firefox:', options)
      @args = make_arguments(**options)
      @driver_opts = Selenium::WebDriver::Firefox::Options.new(args: @opts)
      setup
    end

    def setup
      Jekyll.logger.info('MakePDF firefox: start driver')
      @driver = Selenium::WebDriver.for :firefox, capabilities: @driver_opts
    end

    def write(url, output)
      @driver.get(url)
      @driver.save_print_page output
    end
  end
end
