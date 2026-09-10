# Passwordless sign-in, modelled on Fizzy's MagicLink: a short 6-character code the
# user types (only accepted in the browser that requested it — see
# Authentication::ViaMagicLink) plus a long single-use token embedded in the emailed
# link, which works from any device. Both share one expiry and either consumes the row.
class MagicLink < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRATION_TIME = 15.minutes

  # How long the "Send email again" button stays disabled for. A mattr_accessor rather
  # than a constant so system tests can shrink it (`MagicLink.resend_cooldown = ...`)
  # instead of waiting out the real cooldown.
  mattr_accessor :resend_cooldown, default: 20.seconds

  belongs_to :user

  has_secure_token :token, length: 36

  scope :active, -> { where(expires_at: Time.current...) }
  scope :stale, -> { where(expires_at: ..Time.current) }

  before_validation :generate_code, on: :create
  before_validation :set_expiration, on: :create

  validates :code, presence: true, uniqueness: true

  class << self
    # Sanitizes user input (spaces, lowercase, O/0 and I/L/1 confusions) before lookup.
    def consume_code(code)
      sanitized = Code.sanitize(code)
      active.find_by(code: sanitized)&.consume if sanitized.present?
    end

    def consume_token(token)
      active.find_by(token: token.to_s)&.consume if token.present?
    end

    def cleanup
      stale.delete_all
    end
  end

  def consume
    destroy
    self
  end

  def expired?
    expires_at <= Time.current
  end

  private
    def generate_code
      self.code ||= loop do
        candidate = Code.generate(CODE_LENGTH)
        break candidate unless self.class.exists?(code: candidate)
      end
    end

    def set_expiration
      self.expires_at ||= EXPIRATION_TIME.from_now
    end
end
