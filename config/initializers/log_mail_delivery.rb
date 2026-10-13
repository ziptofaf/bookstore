class LogMailDelivery
  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    Rails.logger.info "[LogMailDelivery] Email to #{Array(mail.to).join(', ')}\n#{mail}"
  end
end

ActionMailer::Base.add_delivery_method :log, LogMailDelivery
