require "test_helper"

module MakePDF
  class PathHelpersTest < Minitest::Test
    def test_path_from_nil_is_dot
      assert_equal Pathname("."), PathObject.path_from(nil)
    end

    def test_path_from_integer
      assert_equal Pathname("5"), PathObject.path_from(5)
    end

    def test_path_from_pathname_like
      assert_equal Pathname("a/b"), PathObject.path_from(Pathname.new("a/b"))
    end

    def test_path_from_string
      assert_equal Pathname("a/b"), PathObject.path_from("a/b")
    end

    def test_path_from_rejects_unsupported_object
      assert_raises(TypeError) { PathObject.path_from(Object.new) }
    end

    def test_join_paths_combines_segments
      assert_equal Pathname("a/b/c"), PathObject.join_paths("a", "b", "c")
    end

    def test_join_paths_single_segment
      assert_equal Pathname("a"), PathObject.join_paths("a")
    end
  end

  class BarePathObject
    include PathObject
  end

  class PathObjectContractTest < Minitest::Test
    def test_stores_joined_path
      assert_equal Pathname("a/b"), BarePathObject.new("a", "b").path
    end

    def test_valid_defaults_to_false
      refute BarePathObject.new("a").valid?
    end

    def test_has_no_root_concept_by_design
      refute BarePathObject.new("a").respond_to?(:root)
    end

    def test_accepts_nil_root_without_raising
      BarePathObject.new("a", root: nil)
    end

    def test_rejects_root_without_scheme
      bad_root = Object.new
      assert_raises(TypeError) { BarePathObject.new("a", root: bad_root) }
    end
  end

  class RootDirTest < Minitest::Test
    def setup
      @base = Dir.mktmpdir
    end

    def teardown
      FileUtils.remove_entry(@base)
    end

    def test_scheme_is_file
      assert_equal "file", RootDir.new(@base).scheme
    end

    def test_create_makes_missing_nested_directories
      target = File.join(@base, "a", "b", "c")
      dir = RootDir.new(target)
      refute dir.valid?
      dir.create
      assert dir.valid?
    end
  end

  class HttpRootTest < Minitest::Test
    def test_scheme_defaults_to_https
      assert_equal "https", HttpRoot.new("example.com", host: "example.com").scheme
    end

    def test_scheme_is_http_when_insecure
      root = HttpRoot.new("example.com", host: "example.com", insecure_connection: true)
      assert_equal "http", root.scheme
    end

    def test_host_reader
      root = HttpRoot.new("example.com", host: "example.com")
      assert_equal "example.com", root.host
    end
  end

  class SourceFileTest < Minitest::Test
    def setup
      @base = Dir.mktmpdir
      @root = RootDir.new(@base)
    end

    def teardown
      FileUtils.remove_entry(@base)
    end

    def test_invalid_when_file_missing
      refute SourceFile.new("report.pdf", root: @root).valid?
    end

    def test_valid_when_file_exists
      FileUtils.touch(File.join(@base, "report.pdf"))
      assert SourceFile.new("report.pdf", root: @root).valid?
    end

    def test_read_yields_lines
      File.write(File.join(@base, "report.pdf"), "line1\nline2\n")
      lines = []
      SourceFile.new("report.pdf", root: @root).read { |line| lines << line }
      assert_equal ["line1\n", "line2\n"], lines
    end

    def test_with_root_returns_same_class
      other_root = RootDir.new(Dir.mktmpdir)
      moved = SourceFile.new("report.pdf", root: @root).with_root(other_root)
      assert_instance_of SourceFile, moved
      assert_equal other_root, moved.root
    end

    def test_to_url_for_local_root
      src = SourceFile.new("report.pdf", root: @root)
      assert_equal "file://#{@base}/report.pdf", src.to_url.to_s
    end

    def test_to_url_after_rerooting_to_http_root
      https_root = HttpRoot.new("/", host: "example.com")
      remote = SourceFile.new("report.pdf", root: @root).with_root(https_root)
      assert_equal "https://example.com/report.pdf", remote.to_url.to_s
    end
  end

  class TargetFileTest < Minitest::Test
    def setup
      @base = Dir.mktmpdir
      @root = RootDir.new(@base)
    end

    def teardown
      FileUtils.remove_entry(@base)
    end

    def test_create_touches_file
      file = TargetFile.new("out.pdf", root: @root)
      refute file.valid?
      file.create
      assert file.valid?
    end

    def test_with_root_rejects_remote_root
      https_root = HttpRoot.new("example.com", host: "example.com")
      file = TargetFile.new("out.pdf", root: @root)
      assert_raises(TypeError) { file.with_root(https_root) }
    end

    def test_with_root_still_works_for_another_file_root
      other_root = RootDir.new(Dir.mktmpdir)
      file = TargetFile.new("out.pdf", root: @root)
      moved = file.with_root(other_root)
      assert_instance_of TargetFile, moved
    end
  end
end
