namespace :waitlist do
  desc "Email every waitlist signup that hasn't been notified yet that the survey is live. Safe to re-run."
  task notify: :environment do
    pending = WaitlistSignup.unnotified.count
    puts "#{pending} address(es) to notify."
    result = WaitlistSignup.notify_all(logger: Logger.new($stdout))
    puts "#{result[:sent]} sent, #{result[:failed]} failed#{' (re-run to retry failures)' if result[:failed] > 0}."
    exit(result[:failed] > 0 ? 1 : 0)
  end
end
