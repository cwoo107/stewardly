# Western (Gregorian) Easter Sunday, by the anonymous Gregorian ("Meeus/Jones/Butcher") algorithm.
module Attendance::Easter
  def self.on(year)
    a = year % 19
    b, c = year.divmod(100)
    d, e = b.divmod(4)
    f = (b + 8) / 25
    g = (b - f + 1) / 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = c.divmod(4)
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) / 451
    month, day = (h + l - 7 * m + 114).divmod(31)
    Date.new(year, month, day + 1)
  end
end
