class ImportTalrooJobsJob < ApplicationJob
  queue_as :xml_feed

  def perform(*tags)
    JobFeedImporters::TalrooJobFeedImport.start(*tags)
  end
end
