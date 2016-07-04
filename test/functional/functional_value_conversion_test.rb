# encoding : UTF-8
require 'test_helper'

class FunctionalValueConversionTest < Minitest::Test

  def setup
    @connection = Vertica::Connection.new(TEST_CONNECTION_HASH)

    @connection.query <<-SQL
      CREATE TABLE IF NOT EXISTS conversions_table (
        "int_field" int,
        "string_field" varchar(100),
        "date_field" date,
        "timestamp_field" timestamp,
        "time_field" time,
        "interval_field" interval,
        "boolean_field" boolean,
        "float_field" float,
        "float_zero" float,
        "binary_field" varbinary,
        "long_varchar_field" long varchar
      )
    SQL
  end


  def teardown
    @connection.query("DROP TABLE IF EXISTS conversions_table CASCADE;")
    @connection.close
  end

  def test_value_conversions
    @connection.query <<-SQL
      INSERT INTO conversions_table VALUES (
          123,
          'hello world',
          '2010-01-01',
          '2010-01-01 12:00:00',
          '12:00:00',
          INTERVAL '1 DAY',
          TRUE,
          1.0,
          0.0,
          HEX_TO_BINARY('d09fd180d0b8d0b2d0b5d1822c2068656c6c6f21'),
          'hello world'
      )
    SQL

    result = @connection.query <<-SQL
      SELECT *,
             float_field / float_zero as infinity,
             float_field / float_zero - float_field / float_zero as nan
        FROM conversions_table LIMIT 1
    SQL

    assert_equal result.rows.length, 1
    assert_equal [
      123,
      'hello world',
      Date.parse('2010-01-01'),
      DateTime.parse('2010-01-01 12:00:00'),
      "12:00:00",
      "1",
      true,
      1.0,
      0.0,
      ['d09fd180d0b8d0b2d0b5d1822c2068656c6c6f21'].pack('H*'),
      'hello world',
      Float::INFINITY,
      Float::NAN
    ], result[0].to_a
  end

  def test_nil_conversions
    @connection.query "INSERT INTO conversions_table VALUES (NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL)"
    result = @connection.query "SELECT * FROM conversions_table LIMIT 1"
    assert_equal result.rows.length, 1
    assert_equal [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil], result[0].to_a
  end

  def test_string_encoding
    assert_equal 'åßç∂ë', @connection.query("SELECT 'åßç∂ë'").the_value
  end

  def test_binary_encoding
    assert_equal ['d09fd180d0b8d0b2d0b5d1822c2068656c6c6f21'].pack('H*'), @connection.query("SELECT HEX_TO_BINARY('d09fd180d0b8d0b2d0b5d1822c2068656c6c6f21')").the_value
    assert_equal Encoding::BINARY, @connection.query("SELECT HEX_TO_BINARY('d09fd180d0b8d0b2d0b5d1822c2068656c6c6f21')").the_value.encoding
  end
end
