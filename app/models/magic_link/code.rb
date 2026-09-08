# Short sign-in codes: RFC 4648 base32 (A–Z, 2–7) — no 0/1/8/9, so the common
# O↔0 and I/L↔1 misreads can be corrected on input instead of rejected.
module MagicLink::Code
  ALPHABET = (("A".."Z").to_a + ("2".."7").to_a).freeze
  CODE_SUBSTITUTIONS = { "O" => "0", "I" => "1", "L" => "1" }.freeze
  REVERSE_SUBSTITUTIONS = { "0" => "O", "1" => "I", "8" => "B", "9" => "G" }.freeze

  class << self
    def generate(length)
      Array.new(length) { ALPHABET[SecureRandom.random_number(ALPHABET.length)] }.join
    end

    # Uppercases, strips spaces/punctuation and maps look-alike digits back onto the
    # base32 alphabet. Returns nil for blank input.
    def sanitize(code)
      return nil if code.blank?
      code.to_s.upcase
        .then { |c| REVERSE_SUBSTITUTIONS.reduce(c) { |result, (from, to)| result.gsub(from, to) } }
        .then { |c| c.gsub(/[^#{ALPHABET.join}]/, "") }
        .presence
    end
  end
end
