require 'minitest/autorun'
require 'where-or'

class WhereOrTest < Minitest::Test
  def test_hello
    assert_equal "hello", WhereOr.hi('hello')
  end
end
