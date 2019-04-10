class ImportZipRecruiterJobsJob < ApplicationJob
  queue_as :job_posting

  def perform(*tags)
    JobFeedImporters::ZipRecruiterJobFeedImporter.start(*tags)
  end
end
