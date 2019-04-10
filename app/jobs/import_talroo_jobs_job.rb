class ImportTalrooJobsJob < ApplicationJob
  queue_as :job_posting

  def perform(*tags)
    JobFeedImporters::TalrooJobFeedImporter.start(*tags)
  end
end
