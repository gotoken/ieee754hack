# frozen_string_literal: true

require "ieee754hack/version"

# Utilities to peek Float internals on IEEE 754 platform.
#
# <code>require "ieee754hack"</code> implies <code>class Float ; include Ieee754hack ; end</code>
#
# === Background
#
# IEEE 754 defines such a bit layout for double precision floating point numbers.
#   0 1           12                                                   64
#   +-+-----------+----------------------------------------------------+
#   |s| e (11bits)|                      m (52bits)                    |
#   +-+-----------+----------------------------------------------------+
#   s: sign (1 for -1, 0 for +1);  e: exponent;  m: mantissa
#
# Depending on the magnitude of the number, five different interpretations are defined.
#   type             e          m   value
#   ---------------------------------------------------------
#   normal     1..2046        any   sign * 1.m * 2**(e-1023)
#   zero             0       zero   sign * 0.0
#   infinity      2047       zero   sign * Infinity
#   nan           2047   non-zero   Not a Number
#   denormal         0   non-zero   sign * 0.m * 2**-1022
#
# where "1.m" stands for a binary string concatenation of "1." and 52 bit binary string m.
#
# This library adds several methods to Float class to inspect those representations.
# For example
#   1.0.human_readable
#   #=> "+1 * 0b1.0000000000000000000000000000000000000000000000000000 * 2**(1023-1023)"
#
# You can see what <code>0.1*3 != 0.3</code> is.
#   [0.1*3, 0.3].map{|e| e.human_readable}
#   #=>
#   #  ["+1 * 0b1.0011001100110011001100110011001100110011001100110100 * 2**(1021-1023)",
#   #   "+1 * 0b1.0011001100110011001100110011001100110011001100110011 * 2**(1021-1023)"]
#
# These outputs differ in the last three bits of the mantissa part: " 100" and "011".
# However this difference depends on the archtecture and implementation version of Ruby,
# so you may get slightly other result.
#
# Each of some special numbers is defined as a constant.
#
# <code>DBL_MINIMUM</code>: the minimum positive normal number
#   0 1           12                                                   64
#   +-+-----------+----------------------------------------------------+
#   |0|00000000001|0000000000000000000000000000000000000000000000000000|
#   +-+-----------+----------------------------------------------------+
#
# <code>DBL_EPSILON</code>: machine epsilon
#   0 1           12                                                   64
#   +-+-----------+----------------------------------------------------+
#   |0|01111001011|0000000000000000000000000000000000000000000000000000|
#   +-+-----------+----------------------------------------------------+
#            (= 0b0.0000000000000000000000000000000000000000000000000001)
#            (= 2.0**-52)
#
# <code>DBL_ULPDENORAL</code>: one ulp for denormal (minimum positive denormal number)
#   0 1           12                                                   64
#   +-+-----------+----------------------------------------------------+
#   |0|00000000000|0000000000000000000000000000000000000000000000000001|
#   +-+-----------+----------------------------------------------------+
#            (= 2.0**(-52-1022))
#            (= 5.0e-324)

module Ieee754hack
  FORM__ = "%b%011b%052b" # :nodoc:

  module ClassMethods
    # returns a Float which has (s, e, m) image where s = 1 for sign = -1
    # and s = 0 for sign = 1.  for arbitrary x except nan, we have
    #     Float::compile(x.sign, x.exponent, x.mantissa) == x
    # and for any nan n
    #     m = Float::compile(n.sign, n.exponent, n.mantissa)
    #     m.sign     == n.sign     and
    #     m.exponent == n.exponent and
    #     m.mantissa == n.mantissa
    #
    # For example
    #     Float.compile(-1, 1024, 0) == -2.0
    #     Float.compile(-1, 1023, 0) == -1.0
    #     Float.compile(-1, 0, 0) == -0.0
    #     Float.compile(+1, 0, 0) == +0.0
    #     Float.compile(+1, 1022, 0) == -0.5
    #     Float.compile(+1, 1021, 0) == -0.25
    #     Float.compile(+1, 1023, 2**50) == +1.25
    #     Float.compile(+1, 2047, 0).infinite?
    #     Float.compile(+1, 2047, rand(2**52)+1).nan?
    def compile(s, e, m)
      [format(FORM__, (s < 0 ? 1 : 0), e, m)].pack("B*").unpack1("G")
    end
  end

  extend(ClassMethods)

  def self.included(base) # :nodoc:
    base.extend(ClassMethods)
  end

  # The machine epsilon for double precision numbers.
  DBL_EPSILON = Ieee754hack.compile(+1, 971, 0)

  # The minumam normal number
  DBL_MINIMUM = Ieee754hack.compile(+1, 1, 0)

  # The magnitude of one ulp for denormal numbers.
  DBL_ULPDENORMAL = Ieee754hack.compile(+1, 0, 1)

  # The positive infinity.
  DBL_INFINITY = Ieee754hack.compile(+1, 2047, 0)

  # Not a number
  DBL_NAN = Ieee754hack.compile(-1, 2047, 2**52 - 1)

  # returns unit in the last place for the finite number. Aliased to ulp().
  # ulp() returns self if self is not finite.  There exists no floating-point
  # number ysuch that x < y < x + x.ulp for any finite x.
  #
  # For example
  #     1.0.ulp                #=> 2**-52
  #     1.0.ulp / 2            #=> 2**-53
  #     1.0 + 1.ulp / 2 == 1.0 #=> true
  def unit_in_the_last_place
    if finite?
      if abs < DBL_MINIMUM
        DBL_ULPDENORMAL
      else
        f = exponent_binary_string.to_i(2) - 52
        Float.compile(1, f < 0 ? 1 : f, 0)
      end
    else
      self # nan or infinity
    end
  end

  alias_method(:ulp, :unit_in_the_last_place)

  # same to ulps_from(0.0) but a little fast.
  def ulps_from_zero
    return self if nan?
    s, e, m = binary_string
    s, e, m = s[0] == "1" ? -1 : 1, e.to_i(2), m.to_i(2)
    s * (e.zero? ? m : (m + e * 2**52))
  end

  # returns number of floatting point numbers on interval [x, self].
  # the value is negative if self < x.
  def ulps_from(x)
    return self if nan?
    return x if x.nan?
    return 0 if x == self
    ulps_from_zero - x.ulps_from_zero
  end

  # tests whether the number is normal or not.
  #
  # For example
  #     1.0.normal?              #=> true
  #     Float::MIN.normal?       #=> true
  #     (Float::MIN / 2).normal? #=> false
  def normal?
    finite? and abs >= DBL_MINIMUM
  end

  # tests whether the number is denormal or not.
  #
  # For example
  #     1.0.denormal?              #=> false
  #     Float::MIN.denormal?       #=> false
  #     (Float::MIN / 2).denormal? #=> true
  def denormal?
    finite? and abs < DBL_MINIMUM and !zero?
  end

  # returns +1 if sign bit is set. etherwise -1.
  #
  # For example
  #     +1.0.sign  #=> +1
  #     -1.0.sign  #=> -1
  def sign
    if finite?
      1 / self > 0 ? 1 : -1
    else
      [self].pack("G").unpack1("B*")[0] == "1" ? -1 : 1
    end
  end

  # returns an array which has three "0"/"1" strings corresponding to
  # sign (length 1), exponent (length 11) and mantissa (length 52) part
  # of the number.
  #
  # For example
  #     1.0.binary_string == ["0", "01111111111", "0000000000000000000000000000000000000000000000000000"]
  def binary_string
    x, = [self].pack("G").unpack("B*")
    [x[0, 1], x[1, 11], x[12, 52]]
  end

  # returns an array consists of three integers mapped from binary_string.
  #
  # For example
  #     1.0.sign_exponent_mantissa == [1, 1023, 0]
  def sign_exponent_mantissa
    s, e, m = binary_string
    sem = []
    sem[0] = s[0] == "1" ? -1 : 1
    sem[1] = e.to_i(2)
    sem[2] = m.to_i(2)
    sem
  end

  alias_method :sem, :sign_exponent_mantissa

  # same to binary_string[1].
  #
  # For example
  #     1.0.exponent_binary_string == "0"
  def exponent_binary_string
    [self].pack("G").unpack1("B*")[1, 11]
  end

  # same to sign_exponent_mantissa[1].
  #
  # For example
  #     1.0.biased_exponent == 1023
  def exponent
    exponent_binary_string.to_i(2)
  end

  # returns biased exponent for finite self.  if the number is not finite
  # biased_exponent() returns self.
  #
  # For example
  #     1.0.biased_exponent == 0
  def biased_exponent
    if finite?
      if abs < DBL_MINIMUM
        -1022
      else
        exponent_binary_string.to_i(2) - 1023
      end
    else
      self
    end
  end

  # same to binary_string[2].
  def mantissa_binary_string
    [self].pack("G").unpack1("B*")[12, 52]
  end

  # same to <code>sign_exponent_mantissa</code><code>[2]</code>.
  def mantissa
    mantissa_binary_string.to_i(2)
  end

  # returns normalized mantissa as rational number for finite self.  if the
  # number is not finite mantissa_fraction() returns self.
  def mantissa_fraction
    d = 2**52

    if finite?
      if zero?
        0
      elsif abs < DBL_MINIMUM
        n = mantissa_binary_string.to_i(2)
        Rational(n, d)
      else
        n = mantissa_binary_string.to_i(2) + d
        Rational(n, d)
      end
    else
      self
    end
  end

  # same to an array [sign(), biased_exponent(), mantissa_fraction()]
  def interpreted_sign_exponent_mantissa
    [sign, biased_exponent, mantissa_fraction]
  end

  # returns a rational number exactly equal to the floating point number.
  # This method would hide numerical error.
  def to_rational
    e = biased_exponent
    if e.negative?
      sign * mantissa_fraction * Rational(1, 2**-e)
    else
      sign * mantissa_fraction * 2**e
    end
  end

  # returns a human readable string representing internal structure.
  #
  # For example
  #
  #     +0.0.human_readable == "+0.0"
  #     -0.0.human_readable == "-0.0"
  #     1.0.human_readable == "+1 * 0b1.0000000000000000000000000000000000000000000000000000 * 2**(1023-1023)"
  #     1.5.human_readable == "+1 * 0b1.1000000000000000000000000000000000000000000000000000 * 2**(1023-1023)"
  #     Float::MIN.human_readable ==
  #                           "+1 * 0b1.0000000000000000000000000000000000000000000000000000 * 2**(1-1023)"
  #     Float::MIN.human_readable ==
  #                           "+1 * 0b1.1111111111111111111111111111111111111111111111111111 * 2**(2046-1023)"
  #     Float::INFINITY.human_readable ==
  #                           "+Infinity"
  #     Float::NAN.human_readable ==
  #                           "NaN <0, 11111111111, 1000000000000000000000000000000000000000000000000000>"
  def human_readable
    if zero?
      format("%c0.0", sign < 0 ? "-" : "+")
    elsif normal?
      format("%+d * 0b1.%s * 2**(%d-1023)",
        sign, mantissa_binary_string, exponent)
    elsif denormal?
      format("%+d * 0b0.%s * 2**-1022", sign, mantissa_binary_string)
    elsif nan?
      format("NaN <%s, %s, %s>", *binary_string)
    else # infinity?
      format("%cInfinity", sign < 0 ? "-" : "+")
    end
  end
end

# Float class is extended by the Ieee754hack module.
class Float
  include Ieee754hack
end
