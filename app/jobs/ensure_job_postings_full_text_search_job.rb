class EnsureJobPostingsFullTextSearchJob < ApplicationJob
  queue_as :job_posting

  def perform(ids)
    JobPosting.where(id: ids).each(&:touch)
  end
end
