require "test_helper"
require "jekyll"
require "make_pdf/jekyll"

module MakePDF
  # A writer stand-in that never touches Chrome, it only records that it
  # was asked to produce `output_file`, optionally simulating a failure.
  class Fake
    def initialize(logger:, output_file:, fail: false, **_options)
      @output_file = Pathname.new(output_file)
      @fail = fail
    end

    def process(_file, **_options)
      raise "simulated render failure" if @fail

      FileUtils.mkdir_p(@output_file.dirname)
      FileUtils.touch(@output_file)
    end
  end

  # Minimal Jekyll::Site double, it only carries what Processor/MakePDFSite
  # read directly, nothing is routed through `_config` option names.
  class FakeSite
    attr_reader :dest, :baseurl, :config, :options, :logger

    def initialize(dir)
      @dest = dir
      @baseurl = "/"
      @config = {
        "url" => "http://example.test",
        "cache_dir" => File.join(dir, ".cache"),
        "make-pdf" => { "log-map-level" => "warn" }
      }
      @options = {}
      @logger = PdfLogger.new(logger: ::Jekyll.logger, level: :warn, name: "test")
    end
  end

  FakeDocument = Struct.new(:path, :name, :data) do
    def destination(_base) = "#{name}.html"
  end

  class KnownIssuesTest < Minitest::Test
    def setup
      @dir = Dir.mktmpdir
      @source = File.join(@dir, "page.md")
      File.write(@source, "content")
      @pdf_path = File.join(@dir, "page.pdf")
    end

    def teardown
      FileUtils.remove_entry(@dir)
    end

    def opted_in_document
      FakeDocument.new(@source, "page", { "make-pdf" => true })
    end

    def test_pdf_removed_from_destination_is_regenerated
      doc = opted_in_document

      first_run = MakePDFSite.new(FakeSite.new(@dir), writer: "fake", output_file: @pdf_path)
      first_run << doc
      first_run.process
      assert File.exist?(@pdf_path), "first run should have created the PDF"

      File.delete(@pdf_path)

      expected_failure do
        second_run = MakePDFSite.new(FakeSite.new(@dir), writer: "fake", output_file: @pdf_path)
        second_run << doc
        second_run.process

        assert File.exist?(@pdf_path),
               "PDF removed from destination should be regenerated even though the source did not change"
      end
    end

    def test_failed_render_is_retried_on_a_later_run
      doc = opted_in_document

      expected_failure do
        failing_run = MakePDFSite.new(FakeSite.new(@dir), writer: "fake", output_file: @pdf_path, fail: true)
        failing_run << doc
        failing_run.process

        recovering_run = MakePDFSite.new(FakeSite.new(@dir), writer: "fake", output_file: @pdf_path, fail: false)
        recovering_run << doc
        recovering_run.process

        assert File.exist?(@pdf_path), "a page whose render failed should be retried once the writer can succeed"
      end
    end

    def test_write_by_default_enables_pages_without_explicit_opt_in
      doc = FakeDocument.new(@source, "page", {})

      expected_failure do
        site = MakePDFSite.new(FakeSite.new(@dir), writer: "fake", output_file: @pdf_path, write_by_default: true)
        site << doc
        site.process

        assert File.exist?(@pdf_path), "write_by_default should queue pages that have not explicitly opted in"
      end
    end
  end
end
