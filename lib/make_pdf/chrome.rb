require "make_pdf/command_based"

module MakePDF
  class Chrome < CommandBased::Writer
    COMMAND = 'chrome-headless-render-pdf'
    DEFAULT_OPTIONS = { # options from 'chrome-headless-render-pdf --help'
      "chrome-binary": nil,
      "chrome-option": nil,
      "remote-host": nil,
      "remote-port": nil,
      "no-margins": true,
      "include-background": true,
      "landscape": false,
      "window-size": nil,
      "paper-width": nil,
      "paper-height": nil,
      "page-ranges": nil,
      "scale": nil,
      "display-header-footer": false,
      "header-template": nil,
      "footer": nil,
      "js-time-budget": nil,
      "animation-time-budget": nil,
    } 

    def initialize(**options)
      super(command: COMMAND, **options.merge(DEFAULT_OPTIONS))
    end

    def map_option_key(key, value)
      case key
      when 'source-url'
        [ '--url', value ]
      when 'output-filename'
        [ '--pdf', value ]
      when DEFAULT_OPTIONS.keys.method(:include?)
        case value
        when false, nil?
          []
        when true, ""
          [ "--#{key.to_s}" ]
        else
          [ "--#{key.to_s}", value ]
        end
      else
        []
      end
    end
  end
end
