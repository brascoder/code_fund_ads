module JobFeedImporters
  class TalrooJobFeedImporter
    URL     = ENV['TALROO_URL']
    OPTIONS = {
      headers: {
        'Content-Type' => 'text/xml',
        'Accept'       => 'text/xml',
      },
      accept_encoding: 'gzip',
    }.freeze

    def self.start
      new.import
    end

    def import
      purge_jobs
      req = Typhoeus::Request.new(URL, OPTIONS)
      req.on_body do |chunk|
        jobs = process_chunk(chunk)
        JobPosting.bulk_insert values: jobs
        binding.pry
      end
      req.run
    end

    private

    def purge_jobs
      JobPosting.talroo.delete_all
    end

    def process_chunk(chunk)
      jobs = []
      Nokogiri::XML::Reader(chunk).each do |node|
        next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
        next unless node.name == 'job'

        fragment = Nokogiri::XML(node.outer_xml)
        break unless fragment.children.present?
        binding.pry

        jobs << extract_job_params(fragment)
      rescue Nokogiri::XML::SyntaxError => e
        Rails.logger.error "#{self.class.name}##{__method__} failed to parse a job! #{e.inspect}"
        next
      end
      jobs
    end

    def extract_job_params(fragment)
      job_params = {}
      remote, remote_country_codes = parse_remote(fragment)

      job_params[:status] = 'active'
      job_params[:source] = 'talroo'
      job_params[:source_identifier] = fragment.css('referencenumber').inner_text
      job_params[:job_type] = parse_job_type(fragment.css('description').inner_text)
      job_params[:company_name] = fragment.css('company').inner_text
      job_params[:title] = fragment.css('title').inner_text
      job_params[:description] = fragment.css('description').inner_text
      job_params[:keywords] = parse_keywords(fragment)
      job_params[:remote] = remote
      job_params[:remote_country_codes] = remote_country_codes

      job_params
    end

    def parse_job_type(description)
      'full_time'
    end

    def parse_keywords(fragment)
      '{}'
    end

    def parse_remote(fragment)
      [false, 'N/A']
    end
  end
end
