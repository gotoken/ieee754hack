# ieee754hack.rb -
=begin
$kNotwork: ieee754hack.rb,v 1.16 2003/10/02 15:29:56 gotoken Exp $

= ieee754hack.rb

== DESCRIPTION

Utilities to peek Float internals on IEEE 754 platform. 

== CONSTANT

--- Float::EPSILON

    is machine epsilon for double precision numbers. 

--- Float::MINIMUM

    is the minimum positive normal number. 

--- Float::ULPDENORMAL

    is one ulp for denormal numbers. 

--- Float::INFINITY

    is positive infinity. 

--- Float::NaN 

    is a NaN. 

== CLASS METHOD

--- Float::compile(sign, e, m)

    returns a Float which has (s, e, m) image where s = 1 for sign = -1 
    and s = 0 for sign = 1.  for arbitrary x except nan, we have

       Float::compile(x.sign, x.exponent, x.mantissa) == x

    and for any nan n

       m = Float::compile(n.sign, n.exponent, n.mantissa)
       m.sign == n.sign and m.exponent == n.exponent and 
         m.mantissa ==n.mantissa

== INSTANCE METHOD

--- Float#unit_in_the_last_place()
--- Float#ulp() 

    returns unit in the last place for the finite number.  ulp() returns
    self if self is not finite.  There exists no floating-point number y
    such that x < y < x + x.ulp for any finite x.

    `ulp' is a synonym for `unit_in_the_last_place'. 

--- Float#ulps_from(x)

    returns number of floatting point numbers on interval [x, self].
    the value is negative if self < x.

--- Float#ulps_from_zero()

    same to ulps_from(0.0) but a little fast. 

       |                          user     system      total        real
       | 1.0.ulps_from(0.0)   1.500000   0.000000   1.500000 (  1.599825)
       | 1.0.ulps_from_zero   1.023438   0.000000   1.023438 (  1.035310)

--- Float#normal?()

    tests whether the number is normal or not. 

--- Float#denormal?()

    tests whether the number is denormal or not. 

--- Float#sign()

    returns 1 if sign bit is set. etherwise -1. 

--- Float#binary_string()

    returns an array which has three "0"/"1" strings corresponding to
    sign (length 1), exponent (length 11) and mantissa (length 52) part 
    of the number. 

--- Float#sign_exponent_mantissa()

    returns an array consists of three integers mapped from binary_string. 

--- Float#exponent_binary_string()

    same to binary_string[1]. 

--- Float#exponent()

    same to sign_exponent_mantissa[1]. 

--- Float#biased_exponent()

    returns biased exponent for finite self.  if the number is not finite
    biased_exponent() returns self.  

--- Float#mantissa_binary_string()

    same to binary_string[2]. 

--- Float#mantissa

    same to sign_exponent_mantissa[2]. 

--- Float#mantissa_fraction()

    returns normalized mantissa as rational number for finite self.  if the
    number is not finite mantissa_fraction() returns self.

--- Float#interpreted_sign_exponent_mantissa

    same to an array [sign(), biased_fraction(), mantissa_fraction()]

--- Float#to_rational

    returns a rational number exactly equal to the floating point number. 
    This method would hide numerical error. 

--- Float#human_readable

    returns a human readable string representing internal structure. 

== AUTHORS

Gotoken

== COPYING

ieee754hack.rb is copyrighted free software by GOTO Kentaro
<gotoken@notwork.org>. You can redistribute it and/or modify it under the 
terms of the Ruby's License ((<URL:http://www.ruby-lang.org/en/LICENSE.txt>)).

== LAST MODIFIED

$Date$

=end
require "rational"

IEEE754HACK_REIVISION = 
  '$kNotwork: ieee754hack.rb,v 1.16 2003/10/02 15:29:56 gotoken Exp $'

if String.instance_method(:to_i).arity.zero?
  # backward compatibility

  class String
    alias_method(:__to_i__, :to_i)
    private :__to_i__

    def to_i(r = 10)
      case r
      when 10
        __to_i__
      when 2
        Integer("0b#{self}")
      when 8
        self.oct
      when 16
        self.hex
      else
        raise(ArgumentError, "illegal radix #{r}")
      end
    end
  end
end

class Float
  # IEEE 754 double precision floating point number
  # 0 1           12                                                   64
  # +-+-----------+----------------------------------------------------+
  # |s| e (11bits)|                      m (52bits)                    |
  # +-+-----------+----------------------------------------------------+
  # s: sign (1 for -1, 0 for +1);  e: exponent;  m: mantissa
  #
  # type             e          m   value
  # ---------------------------------------------------------
  # normal     1..2046        any   sign * 1.m * 2**(e-1023)
  # zero             0       zero   sign * 0.0
  # infinity      2047       zero   sign * Infinity
  # nan           2047   non-zero   Not a Number
  # denormal         0   non-zero   sign * 0.m * 2**-1022
  #
  # MINIMUM: minimum positive normal number
  # +-+-----------+----------------------------------------------------+
  # |0|00000000001|0000000000000000000000000000000000000000000000000000|
  # +-+-----------+----------------------------------------------------+
  #
  # ULPDENORAL: one ulp for denormal (minimum positive denormal number)
  # +-+-----------+----------------------------------------------------+
  # |0|00000000000|0000000000000000000000000000000000000000000000000001|
  # +-+-----------+----------------------------------------------------+
  #
  # EPSILON: machine epsilon
  # 0 1           12                                                   64
  # +-+-----------+----------------------------------------------------+
  # |0|01111001011|0000000000000000000000000000000000000000000000000000|
  # +-+-----------+----------------------------------------------------+
  #         (= 0b0.0000000000000000000000000000000000000000000000000001)

  FORM__ = "%b%011b%052b"

  def self::compile(s, e, m)
    [format(FORM__, (s<0 ? 1 : 0), e, m)].pack("B*").unpack("G").first
  end

  module Constants
    EPSILON = Float::compile(+1, 971, 0)
    MINIMUM = Float::compile(+1, 1, 0)
    ULPDENORMAL = Float::compile(+1, 0, 1)
    INFINITY = Float::compile(+1, 2047, 0)
    NaN = Float::compile(-1, 2047, 2**52-1)
  end

  include Constants

  def unit_in_the_last_place()
    if finite?
      if zero?
        ULPDENORMAL
      elsif abs < MINIMUM
        ULPDENORMAL
      else
        f = exponent_binary_string.to_i(2) - 52
        Float::compile(1, f<0 ? 1 : f, 0)
      end
    else
      self # nan or infinity
    end
  end

  def ulps_from_zero()
    return self if nan?
    s, e, m = binary_string
    s, e, m = s[0] == ?1 ? -1 : 1, e.to_i(2), m.to_i(2)
    s * (e.zero? ? m : (m + e*2**52))
  end

  def ulps_from(x)
    return self if nan?
    return x if x.nan?
    return 0 if x == self
    ulps_from_zero - x.ulps_from_zero
  end

  def normal?()
    finite? and abs >= MINIMUM
  end

  def denormal?()
    finite? and abs < MINIMUM and not zero?
  end

  def sign()
    if finite?
      1/self > 0 ? 1 : -1
    else
      [self].pack("G").unpack("B*").first[0] == ?1 ? -1 : 1
    end
  end

  def binary_string()
    x, = [self].pack("G").unpack("B*")
    [x[0,1], x[1,11], x[12,52]]
  end

  def sign_exponent_mantissa()
    sem = binary_string
    sem[0] = s[0] == ?1 ? -1 : 1
    sem[1] = e.to_i(2)
    sem[2] = m.to_i(2)
    sem
  end

  def exponent_binary_string
    [self].pack("G").unpack("B*").first[1,11]
  end

  def exponent
    exponent_binary_string.to_i(2)
  end

  def biased_exponent()
    if finite?
      if abs < MINIMUM
        -1022
      else
        exponent_binary_string.to_i(2) - 1023
      end
    else
      self
    end
  end

  def mantissa_binary_string()
    [self].pack("G").unpack("B*").first[12,52]
  end

  def mantissa
    mantissa_binary_string.to_i(2)
  end

  def mantissa_fraction()
    d = 2**52

    if finite?
      if zero?
        0
      elsif abs < MINIMUM
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

  def interpreted_sign_exponent_mantissa()
    [sign, biased_exponent, mantissa_fraction]
  end

  def to_rational()
    e = biased_exponent
    if e < 0
      sign * mantissa_fraction * Rational(1, 2**-e)
    else
      sign * mantissa_fraction * 2**e
    end
  end

  def human_readable
    if zero?
      format("%c0.0", sign < 0 ? ?- : ?+ )
    elsif normal?
      format("%+d * 0b1.%s * 2**(%d-1023)", 
             sign, mantissa_binary_string, exponent)
    elsif denormal?
      format("%+d * 0b0.%s * 2**-1022", sign, mantissa_binary_string)
    elsif nan?
      format("NaN <%s, %s, %s>", *binary_string)
    else # infinity?
      format("%cInfinity", sign < 0 ? ?- : ?+)
    end
  end

  alias_method(:ulp, :unit_in_the_last_place)
end

if __FILE__ == $0

  # boundary conditions

  puts "%.16E" % Float::EPSILON  #=> 2.2204460492503131E-16
  puts "%.16E" % Float::MINIMUM  #=> 2.2250738585072014E-308

  # ulp and epsilon

  p Float::EPSILON == 1.0.ulp  #=> true

  p 1.0 == 1.0 + 1.0.ulp       #=> false
  p 1.0 == 1.0 + 1.0.ulp/2     #=> true

  p 1.0.ulp == 1.9999.ulp      #=> true
  p 1.0.ulp == 2.0.ulp         #=> false

end
