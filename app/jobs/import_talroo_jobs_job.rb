class ImportTalrooJobsJob < ApplicationJob
  queue_as :default

  def perfrom(*tags)
    JobFeedImporters::TalrooJobFeedImport.start(*tags)
  end
end
