class ImportZipRecruiterJobsJob < ApplicationJob
  queue_as :xml_feed

  def perform(*tags)
    JobFeedImporters::ZipRecruiterJobFeedImport.start(*tags)
  end
end
