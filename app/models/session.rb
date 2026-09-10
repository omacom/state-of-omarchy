# A signed-in browser. The session cookie itself never expires, but the row it
# points at does: sessions log out after a stretch of inactivity, or outright once
# a year, so a leaked cookie doesn't stay valid forever. Revoking sooner is just
# `session.destroy` (e.g. from a "sign out everywhere" action).
class Session < ApplicationRecord
  IDLE_TIMEOUT = 90.days
  MAX_LIFETIME = 1.year

  belongs_to :user

  before_validation :set_last_active_at, on: :create

  scope :stale, -> { where("last_active_at < :idle OR created_at < :max", idle: IDLE_TIMEOUT.ago, max: MAX_LIFETIME.ago) }

  class << self
    def cleanup
      stale.delete_all
    end
  end

  def expired?
    last_active_at < IDLE_TIMEOUT.ago || created_at < MAX_LIFETIME.ago
  end

  # Called on every authenticated request; throttled so a busy user isn't writing
  # to the sessions table on each page load.
  def touch_activity
    update_column(:last_active_at, Time.current) if last_active_at < 1.hour.ago
  end

  private
    def set_last_active_at
      self.last_active_at ||= Time.current
    end
end
