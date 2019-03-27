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
      req = Typhoeus::Request.new(URL, OPTIONS)
      req.on_body do |chunk|
        process_chunk(chunk)
      end
      req.run
    end

    private

    def process_chunk(chunk)
      Nokogiri::XML::Reader(chunk).each do |node|
        next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
        next unless node.name == "job"
        job_params = extract_job_params(node)
        JobPosting.create(job_params)
      end
    end

    def extract_job_params(node)
      job_params = {}
      fragment = Nokogiri::XML(node.outer_xml)

      job_params[:status] = 'active'
      job_params[:source] = 'talroo'
      job_params[:source_identifier] = fragment.css('referencenumber').inner_text
      job_params[:job_type] = parse_job_type(fragment.css('description').inner_text)
      job_params[:company_name] = fragment.css('company').inner_text
      job_params[:title] = fragment.css('title').inner_text
      job_params[:description] = fragment.css('description').inner_text
      job_params[:keywords] = parse_keywords(fragment)
      job_params
    end

    def parse_job_type(description)
      'full_time'
    end

    def parse_keywords(fragment)
      ''
    end
  end
end
