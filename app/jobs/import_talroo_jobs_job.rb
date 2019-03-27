class ImportTalrooJobsJob < ApplicationJob
  queue_as :default

  def perfrom
    TalrooJobFeedImport.start
  end
end
