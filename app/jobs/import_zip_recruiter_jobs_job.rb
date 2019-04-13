class ImportZipRecruiterJobsJob < ApplicationJob
  queue_as :job_posting

  URL = ENV['ZIP_RECRUITER_URL']

  def perform(*tags)
    JobPosting.zip_recruiter.delete_all
    open URL do |file|
      reader = Zlib::GzipReader.new(file)
      Nokogiri::XML::Reader(reader).each do |node|
        next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
        next unless node.name == 'job'

        CreateZipRecruiterJobPostingJob.perform_later node.outer_xml, tags
      end
    end
  end
end
