# frozen_string_literal: true

require "test_helper"

class Ieee754hackTest < Test::Unit::TestCase
  test "VERSION" do
    assert do
      ::Ieee754hack.const_defined?(:VERSION)
    end
  end

  test "sign" do
    assert_equal(+1.0.sign, +1)
    assert_equal(-1.0.sign, -1)
    assert_equal(+0.0.sign, +1)
    assert_equal(-0.0.sign, -1)
    assert_equal((+Float::INFINITY).sign, +1)
    assert_equal((-Float::INFINITY).sign, -1)
  end

  test "binary_string" do
    assert_equal(0.125.binary_string,
      ["0", "01111111100", "0000000000000000000000000000000000000000000000000000"])
    assert_equal(0.1.binary_string,
      ["0", "01111111011", "1001100110011001100110011001100110011001100110011010"])
  end

  test "sign_exponent_mantissa" do
    assert_equal(0.125.sign_exponent_mantissa,
      [1, 1020, 0])
    assert_equal(0.1.sign_exponent_mantissa,
      [1, 1019, 2702159776422298])
  end

  test "exponent_binary_string" do
    normal = 0.5
    denormal = Float::MIN.ulp
    assert_equal(normal.exponent_binary_string, "01111111110")
    assert_equal(denormal.exponent_binary_string, "00000000001")
  end

  test "exponent" do
    normal = 0.5
    denormal = Float::MIN.ulp
    assert_equal(normal.exponent, 1022)
    assert_equal(denormal.exponent, 1)
  end

  test "biased_exponent" do
    normal = 0.5
    denormal = Float::MIN / 2

    assert_equal(normal.biased_exponent, -1)
    assert_equal(denormal.biased_exponent, -1022)
    assert_equal(Float::INFINITY.biased_exponent, Float::INFINITY)
  end

  test "mantissa_binary_string" do
    assert_equal(0.0.mantissa_binary_string, "0000000000000000000000000000000000000000000000000000")
    assert_equal(1.0.mantissa_binary_string, "0000000000000000000000000000000000000000000000000000")
    assert_equal(0.5.mantissa_binary_string, "0000000000000000000000000000000000000000000000000000")
    assert_equal(0.1.mantissa_binary_string, "1001100110011001100110011001100110011001100110011010")
  end

  test "mantissa" do
    assert_equal(0.0.mantissa, 0)
    assert_equal(1.0.mantissa, 0)
    assert_equal(2.0.mantissa, 0)
    assert_equal(Float::EPSILON.mantissa, 0)
    assert_equal(Float::MIN.mantissa, 0)
    assert_equal(Float::MAX.mantissa, 2**52 - 1)
  end

  test "mantissa_fraction" do
    assert_equal(0.0.mantissa_fraction, 0)
    assert_equal(1.0.mantissa_fraction, 1r)
    assert_equal(0.5.mantissa_fraction, 1r)
    assert_equal(3.0.mantissa_fraction, 1.5r)
    assert_equal((Float::MIN / 2).mantissa_fraction, 0.5r)
    assert_equal(Float::INFINITY.mantissa_fraction, Float::INFINITY)
  end

  test "interpreted_sign_exponent_mantissa" do
    assert_equal(0.0.interpreted_sign_exponent_mantissa, [1, -1022, 0])
    assert_equal(1.0.interpreted_sign_exponent_mantissa, [1, 0, 1])
  end

  test "to_rational" do
    assert_equal(0.0.to_rational, 0r)
    assert_equal(1.0.to_rational, 1.0r)
    assert_equal(0.5.to_rational, 0.5r)
    assert_equal(0.1.to_rational, 0.1.to_r)
  end

  test "normal?" do
    assert_true(0.5.normal?)
    assert_true(-0.5.normal?)
    assert_true(Float::MIN.ulp.normal?)
    assert_true((-Float::MIN.ulp).normal?)
    assert_false((Float::MIN.ulp / 2).normal?)
    assert_false(Float::INFINITY.normal?)
    assert_false(Float::NAN.normal?)
    assert_false(0.0.normal?)
  end

  test "constants" do
    assert_equal(Ieee754hack::DBL_EPSILON, Float::EPSILON)
    assert_equal(Ieee754hack::DBL_EPSILON.object_id, Float::EPSILON.object_id)
    assert_equal(Ieee754hack::DBL_MINIMUM, Float::MIN)
    assert_equal(Ieee754hack::DBL_INFINITY, Float::INFINITY)
  end

  test "boudary conditions" do
    assert_equal(sprintf("%.16E", Ieee754hack::DBL_EPSILON), "2.2204460492503131E-16")
    assert_equal(sprintf("%.16E", Ieee754hack::DBL_MINIMUM), "2.2250738585072014E-308")
  end

  test "ulp" do
    assert_equal(Float::EPSILON, 1.0.ulp)
    assert_not_equal(1.0, 1.0 + 1.0.ulp)
    assert_equal(1.0, 1.0 + 1.0.ulp / 2)
    assert_equal(1.0.ulp, 1.9999.ulp)
    assert_not_equal(1.0.ulp, 2.0.ulp)
    assert_equal(0.0.ulp, Ieee754hack::DBL_ULPDENORMAL)
    assert_equal(Float::INFINITY.ulp.infinite?, 1)
    assert_equal((-Float::INFINITY).ulp.infinite?, -1)
    assert_true(Float::NAN.ulp.nan?)
  end

  test "ulp_from_zero" do
    assert_equal(0.0.ulps_from_zero, 0)
    assert_true(Float::NAN.ulps_from_zero.nan?)
  end

  test "ulp_from" do
    assert_equal(0.0.ulps_from(0.0), 0)
    assert_true(Float::NAN.ulps_from(0.0).nan?)
    assert_equal(0.3.ulps_from(0.1 * 3).abs, 1)
  end

  test "human_readable" do
    pzero = +0.0
    mzero = -0.0
    normal = 1.0
    denormal = Float.compile(1, 0, 1)
    nan = Float::NAN
    pinfinity = +Float::INFINITY
    minfinity = -Float::INFINITY

    assert_equal(pzero.human_readable, "+0.0")
    assert_equal(mzero.human_readable, "-0.0")
    assert_equal(normal.human_readable,
      "+1 * 0b1.0000000000000000000000000000000000000000000000000000 * 2**(1023-1023)")
    assert_equal(denormal.human_readable,
      "+1 * 0b0.0000000000000000000000000000000000000000000000000001 * 2**-1022")
    assert_equal(nan.human_readable,
      "NaN <0, 11111111111, 1000000000000000000000000000000000000000000000000000>")
    assert_equal(pinfinity.human_readable,
      "+Infinity")
    assert_equal(minfinity.human_readable,
      "-Infinity")
  end
end
