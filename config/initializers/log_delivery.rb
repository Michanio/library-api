# An Action Mailer delivery method that writes each email to the Rails log instead
# of sending it. The brief doesn't require real delivery, so development and
# production use it (`config.action_mailer.delivery_method = :log`).
class LogDelivery
  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    Rails.logger.info <<~EMAIL
      [LogDelivery] Email not sent, logged instead:
      From: #{mail.from.join(", ")}
      To: #{mail.to.join(", ")}
      Subject: #{mail.subject}

      #{mail.body.decoded}
    EMAIL
  end
end

ActiveSupport.on_load(:action_mailer) do
  add_delivery_method :log, LogDelivery
end
