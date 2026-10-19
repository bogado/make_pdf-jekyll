$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "pdf_document"

class Minitest::Test
  # Marks a test body as covering a feature that is not implemented yet.
  # Passes (as a skip) while the code raises, and fails loudly once the
  # code stops raising, so the real assertions can be restored.
  def expected_failure
    yield
  rescue Minitest::Assertion, StandardError, NotImplementedError => e
    skip("Expected failure (not yet implemented): #{e.message}")
  else
    flunk("Expected failure now passes! Update the test to assert the real behavior.")
  end
end
