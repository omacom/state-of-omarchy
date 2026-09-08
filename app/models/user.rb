class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :responses, dependent: :destroy

  normalizes :email_address, with: ->(value) { value.to_s.strip.downcase.presence }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Mints a fresh link + code and emails both. Delivery is synchronous on purpose:
  # the sign-in form needs to tell the user when the email could not be sent.
  def send_magic_link
    magic_links.create!.tap do |magic_link|
      MagicLinkMailer.sign_in_instructions(magic_link).deliver_now
    end
  end
end
