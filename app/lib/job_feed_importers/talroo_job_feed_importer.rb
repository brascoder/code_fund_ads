module JobFeedImporters
  class TalrooJobFeedImporter
    URL     = ENV['TALROO_URL']
    BUFFER_LIMIT = 10 * 1024 * 1024
    OPTIONS = {
      headers: {
        'Content-Type' => 'text/xml',
        'Accept'       => 'text/xml',
      },
      accept_encoding: 'gzip',
    }.freeze

    def self.start(*tags)
      new(*tags).import
    end

    def initialize(*tags)
      @tags = tags.flatten
    end

    def import
      purge_jobs

      job_buffer = ''
      req = Typhoeus::Request.new(URL, OPTIONS)
      req.on_body do |chunk|
        job_buffer << chunk
        if job_buffer.size > BUFFER_LIMIT
          jobs = process_buffer(job_buffer)
          JobPosting.bulk_insert values: jobs if jobs.present?
          job_buffer = ''
        end
      end
      req.run
    end

    private

    def purge_jobs
      JobPosting.talroo.delete_all
    end

    def process_buffer(buffer)
      jobs = []
      clean_buffer = groom_buffer(buffer)

      Nokogiri::XML::Reader(clean_buffer).each do |node|
        next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
        next unless node.name == 'job'

        fragment = Nokogiri::XML(node.outer_xml)
        break unless fragment.children.present?

        job = extract_job_params(fragment)
        jobs << job unless job.nil?
      rescue Nokogiri::XML::SyntaxError => e
        Rails.logger.error "#{self.class.name}##{__method__} failed to parse a job! #{e.inspect}"
        next
      end
      jobs
    end

    def groom_buffer(buffer)
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" \
        "<feed>\n" \
        "#{buffer.slice(buffer.index('<job>')..-1)}" \
        '</feed>'
    end

    def extract_job_params(fragment)
      keywords = parse_keywords(fragment)
      # return nil if keywords.empty?

      job_params = {}
      province_code, country_code = parse_province(fragment.css('state').inner_text)

      job_params[:status] = 'active'
      job_params[:source] = ENUMS::JOB_SOURCES::TALROO
      job_params[:source_identifier] = fragment.css('referencenumber').inner_text
      job_params[:job_type] = parse_job_type(fragment.css('title').inner_text)
      job_params[:company_name] = fragment.css('company').inner_text
      job_params[:title] = fragment.css('title').inner_text
      job_params[:description] = fragment.css('description').inner_text
      job_params[:keywords] = keywords
      job_params[:min_annual_salary_cents] = 0
      job_params[:min_annual_salary_currency] = 'USD'
      job_params[:max_annual_salary_cents] = 0
      job_params[:max_annual_salary_currency] = 'USD'
      job_params[:remote] = false
      job_params[:remote_country_codes] = '{}'
      job_params[:city] = fragment.css('city').inner_text
      job_params[:province_code] = province_code
      job_params[:country_code] = country_code
      job_params[:url] = fragment.css('url').inner_text
      job_params[:start_date] = Chronic.parse(fragment.css('date').inner_text).to_date
      job_params[:end_date] = Date.today
      job_params[:auto_renew] = false

      job_params
    end

    def parse_job_type(title)
      # Done this way so that jobs with both full-time and part-time
      # in the title will be set to full-time
      full_time = ['Full-Time', 'Full-time', 'full-time']
      return ENUMS::JOB_TYPES::FULL_TIME if full_time.any? { |f| title.include?(f) }

      part_time = ['Part-Time', 'Part-time', 'part-time']
      return ENUMS::JOB_TYPES::PART_TIME if part_time.any? { |p| title.include?(p) }

      ENUMS::JOB_TYPES::FULL_TIME
    end

    def parse_keywords(fragment)
      categories = []
      keywords   = []

      %w(major minor).each do |type|
        (0..2).each do |index|
          category = "#{type}_category#{index}"
          categories << fragment.css(category).inner_text
        end
      end

      categories.map! { |cat| cat.delete('[').delete('[').downcase }
      job_tags = @tags.filter { |tag| tag.length > 1 && categories.include?(tag) }
      job_tags.each do |tag|
        ENUMS::KEYWORDS.keys.each do |key|
          keywords << key if ENUMS::KEYWORDS[key].include?(tag)
        end
      end

      keywords.uniq.compact.sort
    end

    def parse_province(fragment)
      province = Province.find("US-#{fragment}")
      return [province.iso_code, 'US'] if province

      [nil, nil]
    end
  end
end
