class WaitlistSignup < ApplicationRecord
  normalizes :email_address, with: ->(value) { value.to_s.strip.downcase.presence }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :unnotified, -> { where(notified_at: nil) }

  # Idempotent: re-submitting an address already on the list is a normal case, not an error.
  # Returns [ signup, already_joined ].
  def self.join(email_address, source: nil)
    normalized = normalize_value_for(:email_address, email_address)
    if (existing = find_by(email_address: normalized))
      [ existing, true ]
    else
      [ create!(email_address: normalized, source: source), false ]
    end
  rescue ActiveRecord::RecordNotUnique
    [ find_by!(email_address: normalized), true ]
  end

  # Emails every unnotified address that the survey is live, marking each as sent as it
  # goes — a run that fails partway through can simply be re-run for what's left.
  def self.notify_all(logger: Rails.logger)
    sent = failed = 0
    unnotified.find_each do |signup|
      WaitlistMailer.launch(signup).deliver_now
      signup.update!(notified_at: Time.current)
      sent += 1
    rescue => e
      failed += 1
      logger.error("waitlist notify failed for #{signup.email_address}: #{e.message}")
    end
    { sent:, failed: }
  end
end
