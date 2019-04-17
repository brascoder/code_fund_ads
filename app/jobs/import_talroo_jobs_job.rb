class ImportTalrooJobsJob < ApplicationJob
  queue_as :job_posting

  URL = ENV['TALROO_URL']

  def perform(*tags)
    JobPosting.talroo.delete_all
    open URL do |file|
      Nokogiri::XML::Reader(file).each do |node|
        if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT && node.name == 'job'
          CreateTalrooJobPostingJob.perform_async node.outer_xml, tags
        end
      end
    end
  end
end
