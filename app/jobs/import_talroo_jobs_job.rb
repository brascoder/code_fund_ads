class ImportTalrooJobsJob < ApplicationJob
  queue_as :job_posting

  URL = ENV['TALROO_URL']

  def perform(*tags)
    JobPosting.talroo.delete_all
    open URL do |file|
      Nokogiri::XML::Reader(file).each do |node|
        next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
        next unless node.name == 'job'

        CreateTalrooJobPostingJob.perform_later node.outer_xml, tags
      end
    end
  end
end
