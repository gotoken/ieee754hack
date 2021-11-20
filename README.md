# Ieee754hack

Utilities to peek Float internals on IEEE 754 platform.

<code>require "ieee754hack"</code> implies <code>class Float ; include Ieee754hack ; end</code>

## Background

IEEE 754 defines such a bit layout for double precision floating point numbers.
```
0 1           12                                                   64
+-+-----------+----------------------------------------------------+
|s| e (11bits)|                      m (52bits)                    |
+-+-----------+----------------------------------------------------+

s: sign (1 for -1, 0 for +1);  e: exponent;  m: mantissa
```

Depending on the magnitude of the number, five different interpretations are defined.
```
type             e          m   value
---------------------------------------------------------
normal     1..2046        any   sign * 1.m * 2**(e-1023)
zero             0       zero   sign * 0.0
infinity      2047       zero   sign * Infinity
nan           2047   non-zero   Not a Number
denormal         0   non-zero   sign * 0.m * 2**-1022
```

where "1.m" stands for a binary string concatenation "1." and 52 bit binary string m.

This library adds several methods to Float class to inspect those representations.
For example
```
1.0.human_readable
#=> "+1 * 0b1.0000000000000000000000000000000000000000000000000000 * 2**(1023-1023)"
```
You can see what <code>0.1*3 != 0.3</code> is.
```
[0.1*3, 0.3].map{|e| e.human_readable}
#=>
#  ["+1 * 0b1.0011001100110011001100110011001100110011001100110100 * 2**(1021-1023)",
#   "+1 * 0b1.0011001100110011001100110011001100110011001100110011 * 2**(1021-1023)"]
```

For more information about IEEE 754, please see https://en.wikipedia.org/wiki/IEEE_754.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ieee754hack'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install ieee754hack

## Usage

```
ri Ieee754hack
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
